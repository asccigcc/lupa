# frozen_string_literal: true

module Lupa
  # Rewrites each raw edge's `dst` to a real node name using the strategy its
  # rel declares (see Rel). Edges that can't be resolved are dropped.
  class Resolver
    # @param nodes [Array<Node>] every node in the repo, unique by name
    # @param associations [Array<(String, String, String)>] [accessor, raw target, owner]
    def initialize(nodes, associations)
      @consts = ConstIndex.new(nodes)
      @accessors = AssociationIndex.new(associations, consts)
    end

    # @param edges [Array<Edge>] raw edges
    # @return [Array<Edge>] resolved, de-duplicated edges
    def call(edges)
      hierarchy = Hierarchy.new(edges, consts)
      edges.filter_map { |edge| resolve(edge, hierarchy.scopes(edge.nesting)) }.uniq
    end

    # Rails' `compute_type` looks an association target up by the owner's
    # *name* ("Shop::Widget" tries Shop::Widget::X, Shop::X, X), not by the
    # lexical scope of the file that declares it.
    # @return [Array<String>] owner's namespaces, innermost first
    def self.owner_nesting(owner)
      parts = owner.split("::")
      parts.size.downto(1).map { |n| parts.first(n).join("::") }
    end

    private

    attr_reader :consts, :accessors

    # @param scopes [Array<String>] where dst is looked up (see Hierarchy#scopes)
    def resolve(edge, scopes)
      target = send(Rel.resolution(edge.rel), edge, scopes)
      edge.with(dst: target, nesting: []) if target
    end

    def marker(edge, _scopes)
      edge.dst
    end

    def constant(edge, scopes)
      consts.resolve(edge.dst, scopes)
    end

    def superclass(edge, scopes)
      consts.resolve(edge.dst, scopes, defining: edge.src)
    end

    def association(edge, _scopes)
      consts.resolve(edge.dst, Resolver.owner_nesting(edge.src))
    end

    # A model constant first, else the unique association target; kept only
    # when it lands on a model, so `SomeService.create` never leaks in.
    def model(edge, scopes)
      target = constant(edge, scopes) || accessors.resolve(edge.dst)
      target if consts.model?(target)
    end
  end
end
