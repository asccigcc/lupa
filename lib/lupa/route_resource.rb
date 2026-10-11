# frozen_string_literal: true

module Lupa
  # One `resources :name` / `resource :name` declaration: the controller it
  # targets, the REST routes it expands to, and the path segment the routes
  # declared inside its block hang off.
  class RouteResource
    # [action, verb, mode, suffix], in the order Rails lists them.
    REST = [
      %w[index GET collection], %w[create POST collection], %w[new GET collection new],
      %w[edit GET member edit], %w[show GET member], %w[update PATCH member],
      %w[update PUT member], %w[destroy DELETE member]
    ].freeze
    ACTIONS = REST.map(&:first).uniq.freeze

    # @param name [String] e.g. "widgets"
    # @param options [Hash{String => Prism::Node}] the declaration's keyword args
    # @param singular [Boolean] whether it is a `resource` (no index, no :id)
    def initialize(name, options, singular:)
      @name = name
      @options = options
      @singular = singular
    end

    # A singular `resource` still routes to a plural controller.
    # @return [String] a route target, e.g. "widgets" or a controller: override
    def controller
      option("controller") || (singular ? Inflector.pluralize(name) : name)
    end

    # @return [String, nil] the module: option, camelized
    def mod
      option("module")&.then { |value| Inflector.camelize(value) }
    end

    # @return [Array<Route>] one per REST action the declaration keeps
    def routes
      REST.filter_map do |action, verb, mode, suffix|
        next unless action?(action)

        Route.new(verb:, path: [segment(mode), suffix].compact.join("/"), target: "#{controller}##{action}")
      end
    end

    # A nested route sits under the parent's own id param (:patient_id).
    # @param mode [String] "collection", "member" or "nested"
    # @return [String] e.g. "widgets", "widgets/:id" or "widgets/:widget_id"
    def segment(mode)
      return url if singular || mode == "collection"

      mode == "member" ? "#{url}/:id" : "#{url}/:#{Inflector.singularize(name)}_id"
    end

    private

    attr_reader :name, :options, :singular

    def action?(action)
      return false if singular && action == "index"

      list("only", ACTIONS).include?(action) && !list("except", []).include?(action)
    end

    def url = option("path") || name

    def option(key) = Ast.literal(options[key])

    def list(key, default)
      options.key?(key) ? Ast.literals(options[key]) : default
    end
  end
end
