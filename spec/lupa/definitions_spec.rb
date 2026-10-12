# frozen_string_literal: true

RSpec.describe Lupa::Definitions do
  def node(name, kind, file)
    Lupa::Node.new(name:, kind:, file:, line: 1)
  end

  def pick(*nodes)
    described_class.call(nodes)
  end

  it "keeps one definition per name" do
    nodes = pick(node("Thing", "model", "app/models/thing.rb"),
                 node("Thing", "interactor", "app/interactors/thing/configurator.rb"))
    expect(nodes.map(&:name)).to eq(["Thing"])
  end

  it "prefers the file the autoloader would load the constant from" do
    nodes = pick(node("Thing", "interactor", "app/interactors/thing/configurator.rb"),
                 node("Thing", "model", "app/models/thing.rb"))
    expect(nodes.first.file).to eq("app/models/thing.rb")
  end

  # `module Api` exists only to namespace what is inside it, so no file spells
  # it and there is nothing better to prefer than the first one read.
  it "keeps the first definition of a namespace no file spells" do
    nodes = pick(node("Api", "concern", "app/controllers/concerns/api/v1/base.rb"),
                 node("Api", "module", "app/interactors/api/sync.rb"))
    expect(nodes.first.file).to eq("app/controllers/concerns/api/v1/base.rb")
  end

  it "preserves the order names were first seen in" do
    nodes = pick(node("B", "model", "app/models/b.rb"), node("A", "model", "app/models/a.rb"),
                 node("B", "other", "app/lib/b.rb"))
    expect(nodes.map(&:name)).to eq(%w[B A])
  end

  it "leaves a route node, which no file defines, alone" do
    nodes = pick(node("GET /things #index", "route", "config/routes.rb"))
    expect(nodes.map(&:kind)).to eq(["route"])
  end
end
