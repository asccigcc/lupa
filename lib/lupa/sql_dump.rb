# frozen_string_literal: true

module Lupa
  # Renders an Extractor::Result as a SQLite-loadable SQL script:
  #   Lupa::SqlDump.call(result) | sqlite3 graph.db
  class SqlDump
    HEADER = [
      "PRAGMA journal_mode=OFF;",
      "BEGIN;",
      "DROP TABLE IF EXISTS nodes;",
      "DROP TABLE IF EXISTS edges;",
      "CREATE TABLE nodes (name TEXT PRIMARY KEY, kind TEXT, file TEXT, line INTEGER);",
      "CREATE TABLE edges (src TEXT, rel TEXT, dst TEXT, line INTEGER);"
    ].freeze

    FOOTER = [
      "CREATE INDEX idx_edges_src ON edges(src);",
      "CREATE INDEX idx_edges_dst ON edges(dst);",
      "COMMIT;"
    ].freeze

    # @param result [#nodes, #edges] typically an Extractor::Result
    # @return [String] the full SQL script, newline-terminated
    def self.call(result)
      new(result).to_s
    end

    def initialize(result)
      @result = result
    end

    # @return [String]
    def to_s
      "#{(HEADER + node_inserts + edge_inserts + FOOTER).join("\n")}\n"
    end

    private

    attr_reader :result

    def node_inserts
      result.nodes.map do |n|
        "INSERT OR IGNORE INTO nodes VALUES (#{values(n.name, n.kind, n.file)}, #{n.line});"
      end
    end

    def edge_inserts
      result.edges.map do |e|
        "INSERT INTO edges VALUES (#{values(e.src, e.rel, e.dst)}, #{e.line});"
      end
    end

    def values(*strings)
      strings.map { |s| Sql.quote(s) }.join(", ")
    end
  end
end
