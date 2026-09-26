# frozen_string_literal: true

module Lupa
  # Per-file accumulator that a Walker and its recognizers write into: the
  # nodes defined, the raw edges found (sourced at the current scope) and the
  # association-name pairs that feed Resolver's `persists` index.
  class Recorder
    attr_reader :nodes, :edges, :associations

    # @param scope [Scope] supplies the `src` of every node and edge
    def initialize(scope)
      @scope = scope
      @nodes = []
      @edges = []
      @associations = []
      @consumed = Set.new.compare_by_identity
    end

    # Records the class/module the scope is currently inside.
    def define(kind, file, line)
      nodes << Node.new(scope.current, kind, file, line)
    end

    # @return [true] so a recognizer can end with it to claim the call
    def add(node, rel, dst)
      edges << Edge.new(scope.current, rel, dst, node.location.start_line)
      true
    end

    # @param name [String] an association accessor, e.g. "orders"
    # @param target [String] the raw constant it points at, e.g. "Order"
    def associate(name, target)
      associations << [name, target]
    end

    # Marks a call node already represented by an enclosing edge (the `.welcome`
    # behind `.deliver_later`). Prism visits the outer call before descending
    # into its receiver, so the mark is always set before the inner call is seen.
    def consume(node)
      consumed.add(node)
    end

    # @return [Boolean] whether node was consumed (clearing the mark)
    def consumed?(node)
      !consumed.delete?(node).nil?
    end

    private

    attr_reader :scope, :consumed
  end
end
