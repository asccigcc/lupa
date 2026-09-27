# frozen_string_literal: true

module Lupa
  # The shortest directed chains between two nodes, by breadth-first search.
  # Done in Ruby rather than a recursive SQL CTE: SQLite can't stop at the
  # first layer that reaches the target, so it enumerates every simple path
  # through hub models first (seconds on a large app instead of milliseconds).
  class Path
    MAX_HOPS = 6
    MAX_PATHS = 10

    # @param edges [Array<(String, String, String)>] distinct [src, rel, dst]
    def initialize(edges)
      @outgoing = edges.group_by(&:first)
    end

    # @param max_hops [Integer] longest chain worth reporting
    # @return [Array<String>] "A -calls-> B -enqueues-> C", at most MAX_PATHS
    def between(from, to, max_hops: MAX_HOPS)
      parents = search(from, to, max_hops)
      parents.key?(to) ? trails(to, parents).first(MAX_PATHS) : []
    end

    private

    attr_reader :outgoing

    # node => [[predecessor, rel], ...] for every node reached, each at the
    # layer where it was first seen, so every recorded chain is a shortest one.
    def search(from, to, max_hops)
      parents = { from => [] }
      frontier = [from]
      max_hops.times { frontier = expand(frontier, parents) unless frontier.empty? || parents.key?(to) }
      parents
    end

    def expand(frontier, parents)
      layer = Hash.new { |hash, node| hash[node] = [] }
      frontier.each { |src| link(src, parents, layer) }
      parents.merge!(layer).then { layer.keys }
    end

    def link(src, parents, layer)
      outgoing.fetch(src, []).each { |_, rel, dst| layer[dst] << [src, rel] unless parents.key?(dst) }
    end

    # Lazy, so a node with many shortest chains is only walked up to MAX_PATHS.
    def trails(node, parents)
      return [node] if parents[node].empty?

      parents[node].lazy.flat_map { |prev, rel| trails(prev, parents).map { |trail| "#{trail} -#{rel}-> #{node}" } }
    end
  end
end
