# frozen_string_literal: true

RSpec.describe Lupa::Walker do
  def walk(src, file: "app/models/widget.rb")
    described_class.new(file:).tap { |walker| Prism.parse(src).value.accept(walker) }
  end

  def edges(src, **)
    walk(src, **).edges.map { |e| [e.src, e.rel, e.dst] }
  end

  # Raw `sends` candidates appear for every `a.b` chain until Resolver checks
  # them, so a spec about another rel looks at that rel alone.
  def edges_of(rel, src)
    edges(src).select { |edge| edge[1] == rel }
  end

  it "defines nested classes with a kind from the file path" do
    nodes = walk("module Shop\n  class Widget; end\nend", file: "app/models/shop/widget.rb").nodes
    expect(nodes.map { |n| [n.name, n.kind, n.line] }).to eq([["Shop", "module", 1], ["Shop::Widget", "model", 2]])
  end

  it "ignores calls outside any class or module" do
    expect(edges("Widget.call")).to be_empty
  end

  it "records inheritance" do
    expect(edges("class Widget < Base; end")).to eq([%w[Widget inherits Base]])
  end

  it "records mixins and organizer steps" do
    src = "class Widget\n  include Trackable\n  organize StepA, StepB\nend"
    expect(edges(src)).to eq([%w[Widget includes Trackable], %w[Widget organizes StepA], %w[Widget organizes StepB]])
  end

  it "records a mailer send once, consuming the inner action call" do
    expect(edges("class Widget\n  def x = WidgetMailer.with(a: 1).hello.deliver_later\nend"))
      .to eq([%w[Widget emails WidgetMailer]])
  end

  it "records dynamic dispatch as a marker keyed on the receiver source" do
    expect(edges("class Widget\n  def x = kind_name.constantize\nend")).to eq([%w[Widget dispatches kind_name]])
  end

  it "records associations and their accessor names" do
    walker = walk("class Widget < ApplicationRecord\n  has_many :parts\n  belongs_to :owner, class_name: 'User'\nend")
    expect(walker.edges.map(&:dst)).to eq(%w[ApplicationRecord Part User])
    expect(walker.associations).to eq([["parts", "Part", "Widget", false], ["owner", "User", "Widget", true]])
  end

  it "drops polymorphic associations" do
    expect(edges("class Widget\n  belongs_to :owner, polymorphic: true\nend")).to be_empty
  end

  it "records positional callback symbols but not their options" do
    expect(edges("class Widget\n  after_save :sync, if: :dirty?\nend")).to eq([%w[Widget triggers sync]])
  end

  it "records writes on a constant or an association accessor, not a local" do
    src = "class Widget\n  def x(rec)\n    Part.create!\n    owner.parts.update_all\n    rec.save\n  end\nend"
    expect(edges_of("persists", src)).to eq([%w[Widget persists Part], %w[Widget persists parts]])
  end

  describe "a freshly built instance" do
    it "is its class's handoff: call is calls, any other method invokes" do
      src = "class Widget\n  def x\n    Builder.new(1).call\n    Builder.new.run\n  end\nend"
      expect(edges(src)).to eq([%w[Widget calls Builder], %w[Widget invokes Builder]])
    end

    it "records a write on a record built from a model or through an association" do
      src = "class Widget\n  def x\n    Part.new(a: 1).save!\n    owner.parts.build.save\n  end\nend"
      expect(edges_of("persists", src)).to eq([%w[Widget persists Part], %w[Widget persists parts]])
    end

    # `new` on a local has no class to name, and a class method called `build`
    # is the app's own, free to return anything.
    it "drops a constructor it cannot type" do
      src = "class Widget\n  def x(klass)\n    klass.new.call\n    Builder.build.call\n    Builder.new\n  end\nend"
      expect(edges(src)).to be_empty
    end
  end

  describe "an instance method sent through an accessor" do
    it "keeps the accessor as dst and the method as the message, for Resolver to check" do
      walker = walk("class Widget\n  def x = current_owner.lock!\nend")
      expect(walker.edges.map { |e| [e.rel, e.dst, e.message] }).to eq([%w[sends current_owner lock!]])
    end

    it "never types a bare local, and leaves the ActiveRecord surface to its own rels" do
      src = "class Widget\n  def x(rec)\n    rec.lock!\n    owner.find_by(a: 1)\n    owner.update(a: 1)\n  end\nend"
      expect(edges_of("sends", src)).to be_empty
    end
  end

  describe "method definitions" do
    let(:every_kind_of_def) do
      <<~RUBY
        class Widget
          def a; end
          def self.b; end
          class << self
            def c; end
          end
          class_methods do
            def d; end
          end
          def e = 1
        end
      RUBY
    end

    it "records instance methods only, however a class method is written" do
      expect(walk(every_kind_of_def).method_defs).to eq([%w[Widget a], %w[Widget e]])
    end

    it "records included and prepended modules, never extended ones" do
      walker = walk("class Widget\n  include A\n  prepend B\n  extend C\nend")
      expect(walker.mixins).to eq([["Widget", "A", ["Widget"]], ["Widget", "B", ["Widget"]]])
    end
  end

  # The write surface is wider than create/update/save: these all reach the
  # database, and each was confirmed against ActiveRecord's own source.
  it "records the whole ActiveRecord write surface" do
    writes = %w[update_columns update_column update_attribute touch increment! decrement! toggle!
                destroy! delete_by destroy_by touch_all update_counters create_or_find_by
                insert_all! reset_counters]
    src = "class Widget\n  def x\n#{writes.map { |write| "    Part.#{write}" }.join("\n")}\n  end\nend"
    expect(edges(src)).to all(eq(%w[Widget persists Part]))
  end

  # increment/decrement/toggle only change the object in memory — only their
  # bang forms reach the database. Recording the plain forms would report a
  # write that never happened, so the list is curated, not generated.
  it "does not read an in-memory mutation as a write" do
    reads = %w[increment decrement toggle becomes reload first_or_initialize build]
    src = "class Widget\n  def x\n#{reads.map { |read| "    owner.parts.#{read}" }.join("\n")}\n  end\nend"
    expect(edges_of("persists", src)).to be_empty
  end

  # Metrics libraries claim increment_counter too, and claiming it for the write
  # surface would suppress the `invokes` edge for every one of those calls.
  it "leaves increment_counter to whoever owns it in the app" do
    expect(edges("class Widget\n  def x = Metrics.increment_counter('a')\nend"))
      .to eq([%w[Widget invokes Metrics]])
  end

  it "classifies constant handoffs and drops the ActiveRecord read surface" do
    src = "class Widget\n  def x\n    Do.call\n    Job.perform_later\n    Part.find(1)\n    Rules.check\n  end\nend"
    expect(edges(src)).to eq([%w[Widget calls Do], %w[Widget enqueues Job], %w[Widget invokes Rules]])
  end
end
