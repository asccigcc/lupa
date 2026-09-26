# frozen_string_literal: true

module Lupa
  # Pure builders for the read queries the CLI runs. Kept separate from the CLI
  # so the SQL is unit-testable without a database or the sqlite3 binary.
  module Queries
    module_function

    # @param name [String] a node name
    # @return [String] every edge pointing at `name` — who calls/enqueues/includes it
    def callers(name)
      "SELECT e.src AS caller, n.kind, e.rel, e.line " \
        "FROM edges e JOIN nodes n ON n.name = e.src " \
        "WHERE e.dst = #{Sql.quote(name)} ORDER BY n.kind, e.src;"
    end

    # @param name [String] a node name
    # @return [String] every edge leaving `name` — what it calls/enqueues/organizes
    def calls(name)
      "SELECT rel, dst AS target, line FROM edges WHERE src = #{Sql.quote(name)} ORDER BY line;"
    end

    # @param name [String] a constant name, bare or namespaced
    # @return [String] where `name` is defined (matches a namespaced constant too)
    def where(name)
      suffix = Sql.quote("%::#{Sql.like_literal(name)}")
      "SELECT name, kind, file, line FROM nodes " \
        "WHERE name = #{Sql.quote(name)} OR name LIKE #{suffix} ESCAPE #{Sql.quote(Sql::LIKE_ESCAPE)};"
    end

    # @return [String] node counts by kind
    def stats_nodes
      "SELECT kind, count(*) n FROM nodes GROUP BY kind ORDER BY n DESC;"
    end

    # @return [String] edge counts by rel
    def stats_edges
      "SELECT rel, count(*) n FROM edges GROUP BY rel ORDER BY n DESC;"
    end
  end
end
