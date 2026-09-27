# frozen_string_literal: true

RSpec.describe Lupa::Hierarchy do
  subject(:hierarchy) { described_class.new(edges, Lupa::ConstIndex.new(nodes)) }

  let(:nodes) { names.map { |name| Lupa::Node.new(name, "other", "f", 1) } }
  let(:names) { %w[Base Mid Leaf ApplicationPolicy ApplicationPolicy::Scope FooPolicy FooPolicy::Scope] }
  let(:edges) do
    [inherits("Mid", "Base"), inherits("Leaf", "Mid"), inherits("FooPolicy", "ApplicationPolicy"),
     inherits("FooPolicy::Scope", "Scope", nesting: %w[FooPolicy])]
  end

  def inherits(src, dst, nesting: [])
    Lupa::Edge.new(src:, rel: "inherits", dst:, file: "f", line: 1, nesting:)
  end

  it "walks the superclass chain, nearest first" do
    expect(hierarchy.ancestors("Leaf")).to eq(%w[Mid Base])
  end

  it "resolves a superclass through the enclosing class's ancestors" do
    expect(hierarchy.ancestors("FooPolicy::Scope")).to eq(%w[ApplicationPolicy::Scope])
  end

  it "extends a nesting with the innermost class's ancestors, after the lexical scopes" do
    expect(hierarchy.scopes(%w[FooPolicy Outer])).to eq(%w[FooPolicy Outer ApplicationPolicy])
    expect(hierarchy.scopes([])).to eq([])
  end

  it "stops at a cycle instead of looping" do
    looped = described_class.new([inherits("Mid", "Leaf"), inherits("Leaf", "Mid")], Lupa::ConstIndex.new(nodes))
    expect(looped.ancestors("Leaf")).to eq(%w[Mid])
  end
end
