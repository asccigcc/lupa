# frozen_string_literal: true

RSpec.describe Lupa::MethodIndex do
  subject(:index) { described_class.new(defs, mixins, hierarchy, consts) }

  let(:consts) { Lupa::ConstIndex.new(%w[Patient Person Billing Notes].map { |name| Lupa::Node.new(name, "model", "f", 1) }) }
  let(:hierarchy) do
    Lupa::Hierarchy.new([Lupa::Edge.new(src: "Patient", rel: "inherits", dst: "Person", file: "f", line: 1)], consts)
  end
  let(:defs) { [%w[Patient cancel!], %w[Person greet], %w[Billing charge], %w[Notes note]] }
  let(:mixins) { [["Patient", "Billing", ["Patient"]], ["Billing", "Notes", ["Billing"]]] }

  it "answers a method the class defines itself" do
    expect(index.defines?("Patient", "cancel!")).to be(true)
  end

  it "follows superclasses and included modules, transitively" do
    expect(%w[greet charge note].map { |name| index.defines?("Patient", name) }).to all(be(true))
  end

  it "knows nothing of a method no repo code defines, or a class it never saw" do
    expect(index.defines?("Patient", "status")).to be(false)
    expect(index.defines?("Ghost", "cancel!")).to be(false)
  end

  context "when modules include each other" do
    let(:mixins) { [["Billing", "Notes", ["Billing"]], ["Notes", "Billing", ["Notes"]]] }

    it "visits each once instead of looping" do
      expect(index.defines?("Billing", "missing")).to be(false)
    end
  end

  context "when a mixin is not defined in the repo" do
    let(:mixins) { [["Patient", "ActiveSupport::Concern", ["Patient"]]] }

    it "ignores it" do
      expect(index.defines?("Patient", "charge")).to be(false)
    end
  end
end
