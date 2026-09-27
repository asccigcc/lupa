# frozen_string_literal: true

module Lupa
  # The superclass chain of each class, resolved from its raw `inherits` edge,
  # so constant lookup can continue past the lexical scope the way Ruby does:
  # enclosing namespaces, then the innermost class's ancestors, then top level.
  #
  # Only superclasses are followed. `includes` merges include/prepend/extend,
  # and an extended module takes no part in constant lookup, so following
  # mixins would sometimes invent a target.
  class Hierarchy
    # @param edges [Array<Edge>] raw edges; only `inherits` ones are used
    # @param consts [ConstIndex] resolves each raw superclass name
    def initialize(edges, consts)
      @declared = edges.select { |edge| edge.rel == "inherits" }.to_h { |edge| [edge.src, edge] }
      @consts = consts
      @parents = {}
    end

    # @param nesting [Array<String>] lexical scope, innermost first
    # @return [Array<String>] where a constant is looked up, in Ruby's order
    def scopes(nesting)
      nesting + (nesting.empty? ? [] : ancestors(nesting.first))
    end

    # @return [Array<String>] superclasses of name defined in the repo, nearest first
    def ancestors(name, seen = [name])
      parent = superclass(name)
      return [] if parent.nil? || seen.include?(parent)

      [parent, *ancestors(parent, seen + [parent])]
    end

    # @return [String, nil] the resolved superclass of name
    def superclass(name)
      return parents[name] if parents.key?(name)

      parents[name] = nil
      parents[name] = resolve(declared[name])
    end

    private

    attr_reader :declared, :consts, :parents

    # The class being defined doesn't exist yet when its superclass is read.
    def resolve(edge)
      consts.resolve(edge.dst, scopes(edge.nesting), defining: edge.src) if edge
    end
  end
end
