# frozen_string_literal: true

module Lupa
  # Renders an Extractor::Result as a SQLite-loadable SQL script:
  #   Lupa::SqlDump.call(result) | sqlite3 graph.db
  class SqlDump
    def self.call(result)
      new(result).to_s
    end

    def initialize(result)
      @result = result
    end

    def to_s
      (header + node_inserts + edge_inserts + footer).join("\n") << "\n"
    end

    private

    def header
      [
        "PRAGMA journal_mode=OFF;",
        "BEGIN;",
        "DROP TABLE IF EXISTS nodes;",
        "DROP TABLE IF EXISTS edges;",
        "CREATE TABLE nodes (name TEXT PRIMARY KEY, kind TEXT, file TEXT, line INTEGER);",
        "CREATE TABLE edges (src TEXT, rel TEXT, dst TEXT, line INTEGER);"
      ]
    end

    def node_inserts
      @result.nodes.map do |n|
        "INSERT OR IGNORE INTO nodes VALUES (#{q(n.name)}, #{q(n.kind)}, #{q(n.file)}, #{n.line});"
      end
    end

    def edge_inserts
      @result.edges.map do |e|
        "INSERT INTO edges VALUES (#{q(e.src)}, #{q(e.rel)}, #{q(e.dst)}, #{e.line});"
      end
    end

    def footer
      [
        "CREATE INDEX idx_edges_src ON edges(src);",
        "CREATE INDEX idx_edges_dst ON edges(dst);",
        "COMMIT;"
      ]
    end

    def q(value)
      "'#{value.to_s.gsub("'", "''")}'"
    end
  end
end
