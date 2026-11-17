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

  it "resolves a route target by its full name only, as Rails does" do
    expect(resolve("routes", "Checkout")).to eq(["Checkout"])
    expect(resolve("routes", "Widget")).to be_empty
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

  describe "a sends edge" do
    let(:nodes) do
      [Lupa::Node.new("Patient", "model", "p", 1), Lupa::Node.new("Billing", "concern", "b", 1),
       Lupa::Node.new("Checkout", "service", "c", 1)]
    end
    let(:record) { [%w[current_patient Patient Patient] + [true]] }

    def sent(accessor, message, accessors: record, src: "Checkout")
      edge = Lupa::Edge.new(src:, rel: "sends", dst: accessor, file: "x.rb", line: 1, message:)
      defs = [%w[Patient cancel!], %w[Billing charge], %w[Checkout run]]
      described_class.new(nodes, accessors, defs, [["Patient", "Billing", ["Patient"]]])
                     .call([edge]).map { |e| [e.dst, e.message] }
    end

    it "lands on the model when it, or a module it includes, defines the method" do
      expect(sent("current_patient", "cancel!")).to eq([%w[Patient cancel!]])
      expect(sent("current_patient", "charge")).to eq([%w[Patient charge]])
    end

    it "drops a method no repo code defines on that model" do
      expect(sent("current_patient", "status")).to be_empty
    end

    it "drops a collection accessor, an ambiguous one and one onto a non-model" do
      expect(sent("patients", "cancel!", accessors: [%w[patients Patient X] + [false]])).to be_empty
      expect(sent("owner", "cancel!", accessors: [%w[owner Patient X] + [true], %w[owner Checkout Y] + [true]]))
        .to be_empty
      expect(sent("checkout", "run", accessors: [%w[checkout Checkout X] + [true]])).to be_empty
    end

    it "drops a model sending to itself" do
      expect(sent("current_patient", "cancel!", src: "Patient")).to be_empty
    end
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
