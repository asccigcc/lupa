# frozen_string_literal: true

RSpec.describe Lupa::Scope do
  subject(:scope) { described_class.new("app/x.rb") }

  def nesting_within(*names)
    return scope.nesting if names.empty?

    scope.within(names.first) { return nesting_within(*names.drop(1)) }
  end

  it "mirrors Module.nesting for nested definitions" do
    expect(nesting_within("Admin", "OrdersController")).to eq(%w[Admin::OrdersController Admin])
  end

  it "keeps only the compact path itself in scope" do
    expect(nesting_within("Admin::OrdersController")).to eq(%w[Admin::OrdersController])
  end

  it "restarts at the top level for a root-anchored definition" do
    expect(nesting_within("Admin", "::Order")).to eq(%w[Order Admin])
  end
end
