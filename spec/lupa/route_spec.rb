# frozen_string_literal: true

RSpec.describe Lupa::Route do
  it "reads the action off the target" do
    expect(described_class.new(verb: "GET", path: "widgets", target: "widgets#index").action).to eq("index")
  end

  it "has no action when the target names only a controller, as Devise's do" do
    expect(described_class.new(verb: "DEVISE", path: "patients/sessions", target: "patients/sessions").action)
      .to be_nil
  end

  it "keeps the action of a target whose controller is the enclosing namespace's" do
    expect(described_class.new(verb: "POST", path: "answers", target: "#answers").action).to eq("answers")
  end
end
