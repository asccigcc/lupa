# frozen_string_literal: true

module Lupa
  # Pure builders for the read queries the CLI runs. Kept separate from the CLI
  # so the SQL is unit-testable without a database or the sqlite3 binary.
  module Queries
    module_function

    # Every edge pointing at `name` — who calls/enqueues/includes/inherits it.
    def callers(name)
      "SELECT e.src AS caller, n.kind, e.rel, e.line " \
        "FROM edges e JOIN nodes n ON n.name = e.src " \
        "WHERE e.dst = #{quote(name)} ORDER BY n.kind, e.src;"
    end

    # Every edge leaving `name` — what it calls/enqueues/organizes/includes.
    def calls(name)
      "SELECT rel, dst AS target, line FROM edges WHERE src = #{quote(name)} ORDER BY line;"
    end

    # Where `name` is defined (matches a namespaced constant too).
    def where(name)
      "SELECT name, kind, file, line FROM nodes " \
        "WHERE name = #{quote(name)} OR name LIKE #{quote("%::#{name}")};"
    end

    def stats_nodes
      "SELECT kind, count(*) n FROM nodes GROUP BY kind ORDER BY n DESC;"
    end

    def stats_edges
      "SELECT rel, count(*) n FROM edges GROUP BY rel ORDER BY n DESC;"
    end

    def quote(value)
      "'#{value.to_s.gsub("'", "''")}'"
    end
  end
end
