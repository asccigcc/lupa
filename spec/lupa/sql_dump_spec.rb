# frozen_string_literal: true

RSpec.describe Lupa::SqlDump do
  subject(:sql) { described_class.call(result) }

  let(:result) do
    Struct.new(:nodes, :edges).new(
      [Lupa::Node.new("Thing", "model", "app/models/thing.rb", 3)],
      [Lupa::Edge.new("ThingsController", "calls", "DoThing", 5)]
    )
  end

  it "creates the nodes and edges tables" do
    expect(sql).to include("CREATE TABLE nodes (name TEXT PRIMARY KEY, kind TEXT, file TEXT, line INTEGER);")
    expect(sql).to include("CREATE TABLE edges (src TEXT, rel TEXT, dst TEXT, line INTEGER);")
  end

  it "wraps the load in a single transaction" do
    expect(sql).to include("BEGIN;")
    expect(sql).to end_with("COMMIT;\n")
  end

  it "emits an insert per node and edge" do
    expect(sql).to include("INSERT OR IGNORE INTO nodes VALUES ('Thing', 'model', 'app/models/thing.rb', 3);")
    expect(sql).to include("INSERT INTO edges VALUES ('ThingsController', 'calls', 'DoThing', 5);")
  end

  it "escapes single quotes to keep the SQL valid" do
    result.nodes << Lupa::Node.new("O'Brien", "other", "app/o'brien.rb", 1)
    expect(described_class.call(result)).to include("'O''Brien'", "'app/o''brien.rb'")
  end
end
