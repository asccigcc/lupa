# frozen_string_literal: true

RSpec.describe Lupa::Queries do
  describe ".callers" do
    it "selects incoming edges pointing at the name" do
      sql = described_class.callers("Order")
      expect(sql).to include("WHERE e.dst = 'Order'")
      expect(sql).to include("JOIN nodes n ON n.name = e.src")
    end
  end

  describe ".calls" do
    it "selects outgoing edges from the name" do
      expect(described_class.calls("CheckoutsController"))
        .to include("WHERE src = 'CheckoutsController'")
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
