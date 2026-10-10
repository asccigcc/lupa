# frozen_string_literal: true

module Lupa
  # What a verb route points at, by Rails' own rules: a "controller#action"
  # `to:` wins; else `action:` / `controller:` override; else a slashed path
  # reads as controller/action (`post "stripe/update"` -> stripe#update); else
  # the path names an action on the enclosing controller (a resource's, a
  # `scope controller:`'s, or — left empty — the namespace's own).
  #
  # A `to:` that isn't a "controller#action" string routes somewhere we can't
  # name — a redirect, a proc, a mounted Rack app — so the route is dropped
  # rather than read off the path, which would invent the enclosing controller.
  class RouteTarget
    SHORTHAND = %r{\A/?[-\w]+/[-\w/]+\z}
    ACTION = /\A[-\w]+\z/

    # @param path [String, nil] the verb's path argument
    # @param options [Hash{String => Prism::Node}] the verb's keyword args
    # @param default [String, nil] the enclosing controller, relative to the modules
    def initialize(path, options, default:)
      @path = path.to_s
      @options = options
      @default = default
    end

    # @return [String, nil] "controller#action"; the controller is relative to
    #   the enclosing modules and may be empty (the namespace's own controller)
    def to_s
      to = option("to")
      return to if to&.include?("#")
      return if options.key?("to")

      "#{controller}##{action}" if action
    end

    private

    attr_reader :path, :options, :default

    def controller
      option("controller") || (shorthand? ? pieces.first : default.to_s)
    end

    def action
      option("action") || (shorthand? ? pieces.last : (path.tr("-", "_") if path.match?(ACTION)))
    end

    # Rails reads the path only when neither to: nor action: is given.
    def shorthand?
      !option("to") && !option("action") && path.match?(SHORTHAND)
    end

    def pieces = path.delete_prefix("/").tr("-", "_").rpartition("/").values_at(0, 2)

    def option(key) = Ast.literal(options[key])
  end
end
