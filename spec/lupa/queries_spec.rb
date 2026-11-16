# frozen_string_literal: true

RSpec.describe Lupa::Queries do
  describe ".callers" do
    it "selects incoming edges pointing at the name" do
      sql = described_class.callers("Order")
      expect(sql).to include("WHERE e.dst = 'Order'")
      expect(sql).to include("JOIN nodes n ON n.name = e.src", "e.file || ':' || e.line AS at")
    end
  end

  describe ".calls" do
    it "selects outgoing edges from the name" do
      expect(described_class.calls("CheckoutsController"))
        .to include("WHERE e.src = 'CheckoutsController'", "e.file || ':' || e.line AS at")
    end
  end

  describe ".impact" do
    it "unions incoming and outgoing edges with where each was found" do
      sql = described_class.impact("Order")
      expect(sql).to include("'in' AS dir", "'out'", "WHERE e.dst = 'Order'", "WHERE e.src = 'Order'")
      expect(sql).to include("e.file || ':' || e.line AS at")
    end
  end

  describe ".callers / .calls / .impact on a sends edge" do
    it "labels the rel with the method it sends" do
      %w[callers calls impact].each do |query|
        expect(described_class.public_send(query, "Order")).to include("e.rel || COALESCE(' #' || e.message, '')")
      end
    end
  end

  describe ".path_edges" do
    it "leaves out markers and, by default, the structural edges no code runs along" do
      expect(described_class.path_edges)
        .to include("rel NOT IN ('dispatches', 'triggers', 'association', 'authenticates')")
    end

    it "follows the structural edges when asked for all of them" do
      sql = described_class.path_edges(all: true)
      expect(sql).to include("rel NOT IN ('dispatches', 'triggers')")
      expect(sql).not_to include("association")
    end

    it "labels a sends hop with its method" do
      expect(described_class.path_edges).to include("SELECT DISTINCT src, rel || COALESCE('#' || message, '') AS label")
    end
  end

  describe ".where" do
    it "matches the exact name or a namespaced suffix" do
      sql = described_class.where("Order")
      expect(sql).to include("name = 'Order'")
      expect(sql).to include("name LIKE '%::Order'")
    end
  end

  describe ".stats_nodes / .stats_edges" do
    it "groups by kind and rel" do
      expect(described_class.stats_nodes).to include("GROUP BY kind")
      expect(described_class.stats_edges).to include("GROUP BY rel")
    end
  end

  describe ".where with LIKE wildcards in the name" do
    it "escapes _ and % so they match literally" do
      expect(described_class.where("Foo_Bar%")).to include("LIKE '%::Foo\\_Bar\\%' ESCAPE '\\'")
    end
  end
end
