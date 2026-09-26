# frozen_string_literal: true

module Lupa
  # Rewrites each raw edge's `dst` to a real node name using the strategy its
  # rel declares (see Rel). Edges that can't be resolved are dropped.
  class Resolver
    # @param nodes [Array<Node>] every node in the repo, unique by name
    # @param associations [Array<(String, String)>] accessor-name pairs from the walkers
    def initialize(nodes, associations)
      @consts = ConstIndex.new(nodes)
      @accessors = AssociationIndex.new(associations, consts)
    end

    # @param edges [Array<Edge>] raw edges
    # @return [Array<Edge>] resolved, de-duplicated edges
    def call(edges)
      edges.filter_map { |edge| resolve(edge) }.uniq
    end

    private

    attr_reader :consts, :accessors

    def resolve(edge)
      target = send(Rel.resolution(edge.rel), edge.dst)
      edge.with(dst: target) if target
    end

    def marker(dst)
      dst
    end

    def constant(dst)
      consts.resolve(dst)
    end

    # A model constant first, else the unique association target; kept only
    # when it lands on a model, so `SomeService.create` never leaks in.
    def model(dst)
      target = constant(dst) || accessors.resolve(dst)
      target if consts.model?(target)
    end
  end
end
