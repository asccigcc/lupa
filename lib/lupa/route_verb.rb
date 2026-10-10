# frozen_string_literal: true

module Lupa
  # One verb call in a routes file (`get`, `post`, …, `match`) read as the
  # routes it declares: one per path (`get :card, :info`) and per verb
  # (`match "x", via: [:get, :post]`), each with its RouteTarget.
  class RouteVerb
    # @param node [Prism::CallNode] the verb call
    # @param default [String, nil] the enclosing controller (see RouteScope#default_controller)
    def initialize(node, default:)
      @node = node
      @default = default
      @options = Ast.keyword_args(node)
    end

    # @return [Array<Route>] one per path and per verb the call declares
    def routes
      targets.product(verbs).map { |(path, target), verb| Route.new(verb:, path:, target:) }
    end

    private

    attr_reader :node, :default, :options

    def targets
      pair = rocket_pair
      pair ? [pair] : paths.filter_map { |path| target(path) }
    end

    def paths
      found = Ast.args(node).filter_map { Ast.literal(_1) }
      found.empty? ? [nil] : found
    end

    def target(path)
      target = RouteTarget.new(path, options, default:).to_s
      [path, target] if target
    end

    # get "p" => "c#a"
    def rocket_pair
      pairs = Ast.each_pair(Ast.args(node).last).map { |key, value| [Ast.literal(key), Ast.literal(value)] }
      pairs.find { |path, target| path && target&.include?("#") }
    end

    # via: :all is any verb; a match without via: keeps its own name.
    def verbs
      return [node.name.to_s.upcase] unless node.name == :match

      via = Ast.literals(options["via"]).map { _1 == "all" ? "ANY" : _1.upcase }
      via.empty? ? ["MATCH"] : via
    end
  end
end
