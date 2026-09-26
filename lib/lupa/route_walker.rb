# frozen_string_literal: true

require "prism"

module Lupa
  # Visits a parsed `config/routes*.rb` file, collecting `route` Nodes and
  # `routes` Edges whose `dst` is the (unresolved) controller constant a route
  # points at. Resolution — and dropping routes to controllers not in the
  # repo — is Resolver's job, same as every other edge.
  #
  # Static only: we mirror Rails' own routing conventions rather than booting
  # the app for `rails routes`. So the long tail — constraints, mounted engines,
  # `concern`s, implicit-controller `verb 'path'` — is under-reported, not lied
  # about, consistent with the rest of lupa.
  class RouteWalker < Prism::Visitor
    HTTP_METHODS = %w[get post put patch delete match].freeze
    HANDLERS = {
      "namespace" => :visit_namespace, "scope" => :visit_scope, "devise_for" => :record_devise,
      "resources" => :record_resource, "resource" => :record_resource
    }.merge(HTTP_METHODS.to_h { |verb| [verb, :record_verb] }).freeze

    attr_reader :nodes, :edges

    # @param file [String] repo-relative path of the routes file
    def initialize(file:)
      super()
      @file = file
      @scope = RouteScope.new
      @nodes = []
      @edges = []
    end

    # Routes declare no model associations; kept so every walker answers the
    # same messages (nodes / edges / associations) for Extractor.
    def associations = []

    # Every handler yields exactly once, so the walk always descends.
    def visit_call_node(node)
      handler = HANDLERS[node.name.to_s]
      return super unless handler

      send(handler, node) { super }
    end

    private

    attr_reader :file, :scope

    # namespace :admin -> module "Admin" AND path "admin".
    def visit_namespace(node, &)
      name = Ast.first_literal(node)
      scope.within(mod: name && Inflector.camelize(name), path: name, &)
    end

    # scope module: :admin -> module only (a positional scope is a path prefix,
    # which affects the label but not the controller constant we care about).
    def visit_scope(node, &)
      mod = Ast.literal(Ast.keyword_args(node)["module"])
      scope.within(mod: mod && Inflector.camelize(mod), &)
    end

    # get "p", to: "c#a" | get "p" => "c#a" (hash-rocket) | post "/p", to: "c#a"
    def record_verb(node)
      path, target = verb_route(node)
      add_route(label(node, path), target, node) if target
      yield
    end

    def verb_route(node)
      to = Ast.literal(Ast.keyword_args(node)["to"])
      to ? [Ast.first_literal(node), to] : rocket_pair(node)
    end

    def rocket_pair(node)
      pairs = Ast.each_pair(Ast.args(node).last).map { |key, value| [Ast.literal(key), Ast.literal(value)] }
      pairs.find { |path, target| path && target&.include?("#") }
    end

    # devise_for :patients, controllers: { registrations: "patients/registrations" }
    def record_devise(node)
      name = Ast.first_literal(node)
      Ast.each_pair(Ast.keyword_args(node)["controllers"]) do |role, value|
        add_route("DEVISE /#{name}/#{role}", Ast.literal(value), node)
      end
      yield
    end

    # resources :widgets | resource :profile | resources :x, controller: "y"
    def record_resource(node)
      name = Ast.first_literal(node)
      add_route(label(node, name), resource_controller(node, name), node) if name
      yield
    end

    # A singular `resource` still routes to a plural controller.
    def resource_controller(node, name)
      override = Ast.literal(Ast.keyword_args(node)["controller"])
      override || (node.name.to_s == "resource" ? Inflector.pluralize(name) : name)
    end

    def label(node, path)
      "#{node.name.to_s.upcase} /#{scope.path(path)}"
    end

    def add_route(label, target, node)
      controller = scope.controller(target)
      return unless controller

      line = node.location.start_line
      nodes << Node.new(label, "route", file, line)
      edges << Edge.new(label, "routes", controller, line)
    end
  end
end
