# frozen_string_literal: true

RSpec.describe Lupa::Path do
  def between(edges, from = "A", to = "D", **)
    described_class.new(edges.map(&:split)).between(from, to, **)
  end

  it "finds the shortest chain, not a longer one" do
    edges = ["A calls B", "B enqueues D", "A invokes C", "C calls B"]
    expect(between(edges)).to eq(["A -calls-> B -enqueues-> D"])
  end

  it "lists every chain of the shortest length" do
    edges = ["A calls B", "B enqueues D", "A invokes C", "C emails D"]
    expect(between(edges)).to eq(["A -calls-> B -enqueues-> D", "A -invokes-> C -emails-> D"])
  end

  it "follows edge direction and survives cycles" do
    edges = ["A calls B", "B calls A", "D calls A"]
    expect(between(edges)).to be_empty
  end

  it "gives up beyond the hop limit" do
    edges = ["A calls B", "B calls C", "C calls D"]
    expect(between(edges, max_hops: 2)).to be_empty
    expect(between(edges, max_hops: 3)).to eq(["A -calls-> B -calls-> C -calls-> D"])
  end

  it "caps how many chains it returns" do
    edges = (1..12).flat_map { |i| ["A calls M#{i}", "M#{i} calls D"] }
    expect(between(edges).size).to eq(described_class::MAX_PATHS)
  end
end
