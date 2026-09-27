# frozen_string_literal: true

module Lupa
  # Pure builders for the read queries the CLI runs. Kept separate from the CLI
  # so the SQL is unit-testable without a database or the sqlite3 binary.
  module Queries
    AT = "e.file || ':' || e.line AS at"

    module_function

    # @param name [String] a node name
    # @return [String] every edge pointing at `name` — who calls/enqueues/includes it
    def callers(name)
      "SELECT e.src AS caller, n.kind, e.rel, #{AT} " \
        "FROM edges e JOIN nodes n ON n.name = e.src " \
        "WHERE e.dst = #{Sql.quote(name)} ORDER BY n.kind, e.src;"
    end

    # @param name [String] a node name
    # @return [String] every edge leaving `name` — what it calls/enqueues/organizes
    def calls(name)
      "SELECT e.rel, e.dst AS target, #{AT} FROM edges e " \
        "WHERE e.src = #{Sql.quote(name)} ORDER BY e.file, e.line;"
    end

    # @param name [String] a node name
    # @return [String] everything one hop from `name`, in and out, with where each edge lives
    def impact(name)
      quoted = Sql.quote(name)
      "SELECT 'in' AS dir, e.rel, e.src AS other, n.kind, #{AT} FROM edges e " \
        "JOIN nodes n ON n.name = e.src WHERE e.dst = #{quoted} UNION ALL " \
        "SELECT 'out', e.rel, e.dst, COALESCE(n.kind, 'marker'), #{AT} FROM edges e " \
        "LEFT JOIN nodes n ON n.name = e.dst WHERE e.src = #{quoted} ORDER BY dir, rel, other;"
    end

    # Markers are left out: their dst is a method name or runtime code, never a
    # node a chain could continue from.
    # @return [String] the distinct edges Path searches over
    def path_edges
      "SELECT DISTINCT src, rel, dst FROM edges WHERE rel NOT IN ('dispatches', 'triggers');"
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
