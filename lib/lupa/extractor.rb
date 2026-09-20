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
      assoc_pairs = []
      each_file do |path, rel|
        walker = Walker.new(file: rel, kind: kind_for(rel))
        Prism.parse(File.read(path)).value.accept(walker)
        nodes.concat(walker.nodes)
        raw_edges.concat(walker.edges)
        assoc_pairs.concat(walker.associations)
      end

      each_route_file do |path, rel|
        walker = RouteWalker.new(file: rel)
        Prism.parse(File.read(path)).value.accept(walker)
        nodes.concat(walker.nodes)
        raw_edges.concat(walker.edges)
      end

      nodes.uniq!(&:name)
      Result.new(nodes, resolve(nodes, raw_edges, assoc_pairs), @scan_dir.delete_prefix("#{@root}/"))
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

    # Rails routes live outside app/ (which each_file scans), so pick them up
    # explicitly: config/routes.rb plus any config/routes/*.rb split files.
    def each_route_file
      route_files.each do |path|
        rel = path.delete_prefix("#{@root}/")
        result = Prism.parse(File.read(path))
        next if result.failure?

        yield path, rel
      end
    end

    def route_files
      main = File.join(@root, "config", "routes.rb")
      files = File.file?(main) ? [main] : []
      files + Dir.glob(File.join(@root, "config", "routes", "*.rb")).sort
    end

    def kind_for(relpath)
      segments = relpath.split("/")
      KIND_BY_DIR.each { |dir, kind| return kind if segments.include?(dir) }
      "other"
    end

    def resolve(nodes, edges, assoc_pairs)
      by_full = {}
      by_short = Hash.new { |h, k| h[k] = [] }
      nodes.each do |n|
        by_full[n.name] = n
        by_short[n.name.split("::").last] << n.name
      end
      aidx = assoc_index(assoc_pairs, by_full, by_short)

      edges.filter_map do |edge|
        # `dispatches` targets are runtime-computed code and `triggers` targets
        # are same-class method names — neither is a constant, so keep them
        # verbatim rather than trying (and failing) to resolve them to a node.
        next edge if %w[dispatches triggers].include?(edge.rel)

        target = if edge.rel == "persists"
                   resolve_persist(edge.dst, by_full, by_short, aidx)
                 else
                   resolve_const(edge.dst, by_full, by_short)
                 end
        next unless target

        Edge.new(edge.src, edge.rel, target, edge.line)
      end.uniq { |e| [e.src, e.rel, e.dst, e.line] }
    end

    # accessor name -> the model it targets, but only when unambiguous. A name
    # declared with conflicting targets across the app (e.g. `child` => both
    # Prescription and Delivery) is dropped rather than guessed.
    def assoc_index(pairs, by_full, by_short)
      idx = Hash.new { |h, k| h[k] = [] }
      pairs.each do |name, raw|
        target = resolve_const(raw, by_full, by_short)
        idx[name] << target if target
      end
      idx.transform_values(&:uniq)
    end

    # A `persists` dst is either a model constant (`Widget.create!`) or an
    # association accessor name (`x.widgets.create!`); resolve the constant first,
    # else the unique association target. Kept only when it lands on a model, so
    # `SomeService.create`-style writes on non-models don't leak in.
    def resolve_persist(dst, by_full, by_short, aidx)
      target = resolve_const(dst, by_full, by_short)
      if target.nil?
        candidates = aidx[dst]
        target = candidates.first if candidates && candidates.size == 1
      end
      return unless target && by_full[target]&.kind == "model"

      target
    end

    def resolve_const(const, by_full, by_short)
      return const if by_full.key?(const)

      candidates = by_short[const.split("::").last]
      candidates.first if candidates.size == 1
    end
  end
end
