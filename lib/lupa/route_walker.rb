# frozen_string_literal: true

require "prism"

module Lupa
  # Visits a parsed `config/routes*.rb` file, reading Rails' routing DSL into
  # Routes and handing each to a RouteRecorder. Only the DSL lives here: what
  # `namespace`, `scope`, `resources` and the verbs mean, and which part of the
  # scope each one shifts. Resolving a route's controller to a class in the repo
  # — and dropping it when there is none — is Resolver's job, as for every edge.
  #
  # Static only: we mirror Rails' own conventions rather than booting the app
  # for `rails routes`. So the long tail — constraints, `concern`s, Devise's
  # default routes, a `draw`n file's enclosing scope — is under-reported, not
  # lied about, consistent with the rest of lupa.
  class RouteWalker < Prism::Visitor
    HTTP_METHODS = %w[get post put patch delete match].freeze
    HANDLERS = {
      "namespace" => :visit_namespace, "scope" => :visit_scope,
      "resources" => :record_resource, "resource" => :record_resource, "root" => :record_root,
      "member" => :visit_on, "collection" => :visit_on, "controller" => :visit_controller, "draw" => :visit_draw,
      "concern" => :skip_concern
    }.merge(HTTP_METHODS.to_h { |verb| [verb, :record_verb] }).freeze

    # @param file [String] repo-relative path of the routes file
    def initialize(file:)
      super()
      @scope = RouteScope.new
      @recorder = RouteRecorder.new(@scope, file:)
    end

    # Extractor reads the walk's result off the walker; the recorder holds it.
    def nodes = recorder.nodes
    def edges = recorder.edges
    def declarations = recorder.declarations

    # Routes declare no model associations; kept so every walker answers the
    # same messages (nodes / edges / associations) for Extractor.
    def associations = []

    # Every handler yields exactly once, so the walk always descends.
    def visit_call_node(node)
      record_integrations(node)
      handler = HANDLERS[node.name.to_s]
      return super unless handler

      send(handler, node) { super }
    end

    private

    attr_reader :scope, :recorder

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
      scope.within(mod: engine_module(Ast.root_constant(node.receiver)), &)
    end

    def engine_module(const)
      const.delete_suffix("::Engine") if const&.end_with?("::Engine")
    end

    # A `concern` body is a template: it declares nothing until a `concerns:`
    # names it, where the enclosing scope differs. Skipping the subtree keeps us
    # from attributing its verbs to the scope the concern is *defined* in.
    def skip_concern(_node); end

    # A gem's own routing words (Devise's `devise_for`) are not Rails', so they
    # add vocabulary here rather than override any of it.
    def record_integrations(node)
      Integrations.route_recognizers.any? { |recognizer| recognizer.call(node, recorder) }
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
      RouteVerb.new(node, default: scope.default_controller).routes.each { recorder.record(_1, node) }
    end

    # root to: "pages#home" | root "pages#home" | root controller: "x", action: :y
    def record_root(node)
      target = root_target(node)
      recorder.record(Route.new(verb: "GET", path: "", target:), node) if target
      yield
    end

    def root_target(node)
      options = Ast.keyword_args(node)
      Ast.literal(options["to"]) || Ast.first_literal(node) ||
        RouteTarget.new(nil, options, default: scope.default_controller).to_s
    end

    # resources :widgets | resource :profile, with their REST routes, then the block
    def record_resource(node, &)
      name = Ast.first_literal(node)
      return yield unless name

      resource = RouteResource.new(name, Ast.keyword_args(node), singular: node.name == :resource)
      scope.within(mod: resource.mod) { record_rest(resource, node, &) }
    end

    def record_rest(resource, node, &)
      resource.routes.each { recorder.record(_1, node) }
      scope.nest(resource, &)
    end
  end
end
