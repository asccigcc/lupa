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
    expect(walker.associations).to eq([%w[parts Part], %w[owner User]])
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

  it "classifies constant handoffs and drops the ActiveRecord read surface" do
    src = "class Widget\n  def x\n    Do.call\n    Job.perform_later\n    Part.find(1)\n    Rules.check\n  end\nend"
    expect(edges(src)).to eq([%w[Widget calls Do], %w[Widget enqueues Job], %w[Widget invokes Rules]])
  end
end
