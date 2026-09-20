# frozen_string_literal: true

require "prism"

module Lupa
  # Walks a repo and produces a resolved interaction graph.
  #
  #   result = Lupa::Extractor.call(root: "/path/to/repo")
  #   result.nodes  # => [Node, ...]
  #   result.edges  # => [Edge, ...]  (dst rewritten to a real node name)
  #
  # Only intra-repo edges survive: an edge is kept when its constant resolves to
  # a node defined in the repo (exact full name, else a unique short name).
  # Everything else is dropped rather than guessed.
  class Extractor
    Result = Struct.new(:nodes, :edges, :scan_label)

    KIND_BY_DIR = {
      "controllers" => "controller", "interactors" => "interactor",
      "models" => "model", "jobs" => "job", "services" => "service",
      "policies" => "policy", "mailers" => "mailer", "components" => "component",
      "serializers" => "serializer"
    }.freeze

    SKIP = %r{/(vendor|node_modules|tmp|\.git|db/migrate|spec|test)/}

    def self.call(root:)
      new(root).call
    end

    def initialize(root)
      @root = File.expand_path(root)
      @scan_dir = File.directory?(File.join(@root, "app")) ? File.join(@root, "app") : @root
    end

    def call
      nodes = []
      raw_edges = []
      each_file do |path, rel|
        walker = Walker.new(file: rel, kind: kind_for(rel))
        Prism.parse(File.read(path)).value.accept(walker)
        nodes.concat(walker.nodes)
        raw_edges.concat(walker.edges)
      end

      nodes.uniq!(&:name)
      Result.new(nodes, resolve(nodes, raw_edges), @scan_dir.delete_prefix("#{@root}/"))
    end

    private

    def each_file
      Dir.glob(File.join(@scan_dir, "**", "*.rb")).sort.each do |path|
        rel = path.delete_prefix("#{@root}/")
        # Match SKIP against the repo-relative path so the tool's own location
        # (e.g. a checkout living under some .../spec/ tree) can't skip a target.
        next if "/#{rel}".match?(SKIP)

        result = Prism.parse(File.read(path))
        next if result.failure?

        yield path, rel
      end
    end

    def kind_for(relpath)
      segments = relpath.split("/")
      KIND_BY_DIR.each { |dir, kind| return kind if segments.include?(dir) }
      "other"
    end

    def resolve(nodes, edges)
      by_full = {}
      by_short = Hash.new { |h, k| h[k] = [] }
      nodes.each do |n|
        by_full[n.name] = n
        by_short[n.name.split("::").last] << n.name
      end

      edges.filter_map do |edge|
        target = resolve_const(edge.dst, by_full, by_short)
        next unless target

        Edge.new(edge.src, edge.rel, target, edge.line)
      end.uniq { |e| [e.src, e.rel, e.dst, e.line] }
    end

    def resolve_const(const, by_full, by_short)
      return const if by_full.key?(const)

      candidates = by_short[const.split("::").last]
      candidates.first if candidates.size == 1
    end
  end
end
