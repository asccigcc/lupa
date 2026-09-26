# frozen_string_literal: true

require "prism"

module Lupa
  # Walks a repo and produces a resolved interaction graph.
  #
  #   result = Lupa::Extractor.call(root: "/path/to/repo")
  #   result.nodes    # => [Node, ...]
  #   result.edges    # => [Edge, ...]  (dst rewritten to a real node name)
  #   result.skipped  # => ["app/models/broken.rb"]  (failed to parse)
  #
  # Only intra-repo edges survive: an edge is kept when its constant resolves to
  # a node defined in the repo. Everything else is dropped rather than guessed.
  class Extractor
    Result = Data.define(:nodes, :edges, :skipped)

    # @param root [String] repo root (ignored when `files` is given)
    # @param files [SourceFiles] which files to read
    # @return [Result]
    def self.call(root: nil, files: SourceFiles.new(root))
      new(files).call
    end

    def initialize(files)
      @files = files
      @skipped = []
    end

    # @return [Result]
    def call
      walkers = walk_all
      nodes = walkers.flat_map(&:nodes).uniq(&:name)
      edges = Resolver.new(nodes, walkers.flat_map(&:associations)).call(walkers.flat_map(&:edges))
      Result.new(nodes:, edges:, skipped:)
    end

    private

    attr_reader :files, :skipped

    def walk_all
      walk(files.ruby_files) { |rel| Walker.new(file: rel) } +
        walk(files.route_files) { |rel| RouteWalker.new(file: rel) }
    end

    # Parses each path once and runs the walker built for it over the tree.
    # Files that fail to parse are skipped (and reported) rather than half-walked.
    def walk(paths, &build)
      paths.filter_map { |path| walk_file(path, &build) }
    end

    def walk_file(path)
      rel = files.relative(path)
      tree = Prism.parse(File.read(path))
      return skip(rel) if tree.failure?

      yield(rel).tap { |walker| tree.value.accept(walker) }
    end

    def skip(rel)
      skipped << rel
      nil
    end
  end
end
