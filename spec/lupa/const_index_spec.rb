# frozen_string_literal: true

RSpec.describe Lupa::ConstIndex do
  subject(:index) { described_class.new(names.map { |name| Lupa::Node.new(name, "model", "f", 1) }) }

  let(:names) { %w[Order Admin::Order Admin::Reports::Daily A::Dup B::Dup Shop::Widget Base Braze::Base] }

  it "binds a bare name in the innermost enclosing namespace first" do
    expect(index.resolve("Order", %w[Admin::OrdersController Admin])).to eq("Admin::Order")
    expect(index.resolve("Dup", %w[A::Thing A])).to eq("A::Dup")
  end

  it "falls back to the top level, then to a unique short name" do
    expect(index.resolve("Order", %w[Billing])).to eq("Order")
    expect(index.resolve("Widget")).to eq("Shop::Widget")
  end

  it "resolves a root-anchored name at the top level only" do
    expect(index.resolve("::Order", %w[Admin])).to eq("Order")
  end

  it "binds the first segment of a path lexically, like Ruby" do
    expect(index.resolve("Reports::Daily", %w[Admin])).to eq("Admin::Reports::Daily")
  end

  it "drops a path whose head binds lexically but whose tail does not exist" do
    expect(index.resolve("Reports::Weekly", %w[Admin])).to be_nil
  end

  it "skips the class being defined, which doesn't exist yet when its superclass is read" do
    expect(index.resolve("Base", %w[Braze], defining: "Braze::Base")).to eq("Base")
  end

  it "drops an ambiguous short name with no lexical or exact match" do
    expect(index.resolve("Dup", %w[C])).to be_nil
  end
end
