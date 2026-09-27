# frozen_string_literal: true

RSpec.describe Lupa::Resolver do
  let(:nodes) do
    [Lupa::Node.new("Order", "model", "a", 1), Lupa::Node.new("Admin::Order", "service", "b", 1),
     Lupa::Node.new("Shop::Widget", "model", "c", 1), Lupa::Node.new("Checkout", "service", "d", 1)]
  end

  def resolve(rel, dst, associations: [])
    edge = Lupa::Edge.new(src: "X", rel:, dst:, file: "x.rb", line: 1)
    described_class.new(nodes, associations).call([edge]).map(&:dst)
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
    expect(resolve("persists", "widgets", associations: [%w[widgets Widget X]])).to eq(["Shop::Widget"])
    expect(resolve("persists", "Checkout")).to be_empty
  end

  it "drops an accessor that maps to more than one model" do
    expect(resolve("persists", "items", associations: [%w[items Order X], %w[items Widget X]])).to be_empty
  end

  it "looks an association target up from the owner's name, as Rails does" do
    edge = Lupa::Edge.new(src: "Admin::Report", rel: "association", dst: "Order", file: "x.rb", line: 1)
    expect(described_class.new(nodes, []).call([edge]).map(&:dst)).to eq(["Admin::Order"])
  end

  it "never records a class inheriting from itself (Pundit's `class Scope < Scope`)" do
    scopes = %w[FooPolicy::Scope BarPolicy::Scope].map { |name| Lupa::Node.new(name, "policy", "p", 1) }
    edge = Lupa::Edge.new(src: "FooPolicy::Scope", rel: "inherits", dst: "Scope", file: "x.rb", line: 1,
                          nesting: %w[FooPolicy])
    expect(described_class.new(scopes, []).call([edge])).to be_empty
  end

  describe "through a class's ancestors" do
    let(:nodes) do
      %w[Client Braze::Base Braze::Base::Client Braze::Sms Braze::Sms::Local Braze::Base::Local]
        .map { |name| Lupa::Node.new(name, "service", "f", 1) }
    end

    def resolved(dst)
      edges = [Lupa::Edge.new(src: "Braze::Sms", rel: "inherits", dst: "Base", file: "f", line: 1, nesting: %w[Braze]),
               Lupa::Edge.new(src: "Braze::Sms", rel: "calls", dst:, file: "f", line: 2, nesting: %w[Braze::Sms Braze])]
      described_class.new(nodes, []).call(edges).map(&:dst).last
    end

    it "finds a constant in the superclass before the top level" do
      expect(resolved("Client")).to eq("Braze::Base::Client")
    end

    it "still prefers the lexical scope over the superclass" do
      expect(resolved("Local")).to eq("Braze::Sms::Local")
    end
  end

  it "de-duplicates identical resolved edges" do
    edges = Array.new(2) { Lupa::Edge.new(src: "X", rel: "calls", dst: "Order", file: "x.rb", line: 1) }
    expect(described_class.new(nodes, []).call(edges).size).to eq(1)
  end
end
