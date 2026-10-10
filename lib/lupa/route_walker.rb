# frozen_string_literal: true

require "prism"

module Lupa
  # Visits a parsed `config/routes*.rb` file, collecting `route` Nodes and
  # `routes` Edges whose `dst` is the (unresolved) controller constant a route
  # points at. A route's label carries its verb, path and action
  # ("GET /widgets/:id #show"), since the edge itself only names the controller.
  # Resolution — and dropping routes to controllers not in the repo — is
  # Resolver's job, same as every other edge.
  #
  # Static only: we mirror Rails' own routing conventions rather than booting
  # the app for `rails routes`. So the long tail — constraints, `concern`s,
  # Devise's default routes, `draw`n files' enclosing scope — is under-reported,
  # not lied about, consistent with the rest of lupa.
  class RouteWalker < Prism::Visitor
    HTTP_METHODS = %w[get post put patch delete match].freeze
    HANDLERS = {
      "namespace" => :visit_namespace, "scope" => :visit_scope, "devise_for" => :record_devise,
      "resources" => :record_resource, "resource" => :record_resource, "root" => :record_root,
      "member" => :visit_on, "collection" => :visit_on, "controller" => :visit_controller, "draw" => :visit_draw
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

    # scope module: :admin -> module only; scope "me" / scope path: "me" -> path
    # only; scope controller: :pages -> the default controller only.
    def visit_scope(node, &)
      options = Ast.keyword_args(node).transform_values { Ast.literal(_1) }
      mod = options["module"] && Inflector.camelize(options["module"])
      scope.within(mod:, path: Ast.first_literal(node) || options["path"], controller: options["controller"], &)
    end

    # controller :pages do ... end
    def visit_controller(node, &)
      scope.within(controller: Ast.first_literal(node), &)
    end

    # An engine's controllers live under its module (`isolate_namespace`, the
    # engine norm): Shop::Engine.routes.draw -> Shop::. The app's own draw, and
    # `draw :file`, add nothing.
    def visit_draw(node, &)
      scope.within(mod: engine_module(node.receiver), &)
    end

    def engine_module(receiver)
      engine = Ast.const_string(receiver.receiver) if Ast.call?(receiver)
      engine.delete_suffix("::Engine") if engine&.end_with?("::Engine")
    end

    # member do ... end / collection do ... end
    def visit_on(node, &)
      scope.on(node.name.to_s, &)
    end

    # get "p", to: "c#a" | get "p" => "c#a" | get :preview, on: :member | post "stripe/update"
    def record_verb(node)
      scope.on(Ast.literal(Ast.keyword_args(node)["on"])) { record_verb_routes(node) }
      yield
    end

    def record_verb_routes(node)
      RouteVerb.new(node, default: scope.default_controller).routes.each do |verb, path, target|
        add_route(label(verb, path, target), target, node)
      end
    end

    # root to: "pages#home" | root "pages#home"
    def record_root(node)
      target = Ast.literal(Ast.keyword_args(node)["to"]) || Ast.first_literal(node)
      add_route(label("GET", "", target), target, node) if target
      yield
    end

    # devise_for :patients, controllers: { registrations: "patients/registrations" }
    def record_devise(node)
      name = Ast.first_literal(node)
      Ast.each_pair(Ast.keyword_args(node)["controllers"]) do |role, value|
        add_route("DEVISE /#{name}/#{role}", Ast.literal(value), node)
      end
      yield
    end

    # resources :widgets | resource :profile, with their REST routes, then the block
    def record_resource(node, &)
      name = Ast.first_literal(node)
      return yield unless name

      resource = RouteResource.new(name, Ast.keyword_args(node), singular: node.name == :resource)
      scope.within(mod: resource.mod) { record_rest(resource, node, &) }
    end

    def record_rest(resource, node, &)
      resource.routes.each do |verb, path, action|
        target = "#{resource.controller}##{action}"
        add_route(label(verb, path, target), target, node)
      end
      scope.nest(resource, &)
    end

    def label(verb, path, target)
      action = target.to_s.split("#", 2).last if target.to_s.include?("#")
      "#{verb} /#{scope.path(path)}#{" ##{action}" if action}"
    end

    def add_route(label, target, node)
      controller = scope.controller(target)
      return unless controller

      line = node.location.start_line
      nodes << Node.new(label, "route", file, line)
      edges << Edge.new(src: label, rel: "routes", dst: controller, file:, line:)
    end
  end
end
