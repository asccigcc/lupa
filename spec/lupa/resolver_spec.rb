# frozen_string_literal: true

RSpec.describe Lupa::Resolver do
  let(:nodes) do
    [Lupa::Node.new("Order", "model", "a", 1), Lupa::Node.new("Admin::Order", "service", "b", 1),
     Lupa::Node.new("Shop::Widget", "model", "c", 1), Lupa::Node.new("Checkout", "service", "d", 1)]
  end

  def resolve(rel, dst, associations: [])
    described_class.new(nodes, associations).call([Lupa::Edge.new("X", rel, dst, 1)]).map(&:dst)
  end

  it "resolves exact names and unique short names" do
    expect(resolve("calls", "Order")).to eq(["Order"])
    expect(resolve("calls", "Widget")).to eq(["Shop::Widget"])
  end

  it "drops unknown constants" do
    expect(resolve("calls", "Stripe")).to be_empty
  end

  it "keeps markers verbatim" do
    expect(resolve("dispatches", "kind.name")).to eq(["kind.name"])
  end

  it "resolves persists through a unique association accessor, only onto models" do
    expect(resolve("persists", "widgets", associations: [%w[widgets Widget]])).to eq(["Shop::Widget"])
    expect(resolve("persists", "Checkout")).to be_empty
  end

  it "drops an accessor that maps to more than one model" do
    expect(resolve("persists", "items", associations: [%w[items Order], %w[items Widget]])).to be_empty
  end

  it "de-duplicates identical resolved edges" do
    edges = Array.new(2) { Lupa::Edge.new("X", "calls", "Order", 1) }
    expect(described_class.new(nodes, []).call(edges).size).to eq(1)
  end
end
