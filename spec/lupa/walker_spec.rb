# frozen_string_literal: true

RSpec.describe Lupa::Walker do
  def walk(src, file: "app/models/widget.rb")
    described_class.new(file:).tap { |walker| Prism.parse(src).value.accept(walker) }
  end

  def edges(src, **)
    walk(src, **).edges.map { |e| [e.src, e.rel, e.dst] }
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
    expect(walker.associations).to eq([%w[parts Part Widget], %w[owner User Widget]])
  end

  it "drops polymorphic associations" do
    expect(edges("class Widget\n  belongs_to :owner, polymorphic: true\nend")).to be_empty
  end

  it "records positional callback symbols but not their options" do
    expect(edges("class Widget\n  after_save :sync, if: :dirty?\nend")).to eq([%w[Widget triggers sync]])
  end

  it "records writes on a constant or an association accessor, not a local" do
    src = "class Widget\n  def x(rec)\n    Part.create!\n    owner.parts.update_all\n    rec.save\n  end\nend"
    expect(edges(src)).to eq([%w[Widget persists Part], %w[Widget persists parts]])
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
    expect(edges(src)).to be_empty
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
