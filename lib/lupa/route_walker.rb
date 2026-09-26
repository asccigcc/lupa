# frozen_string_literal: true

require "prism"

module Lupa
  # Visits a parsed `config/routes*.rb` file, collecting `route` Nodes and
  # `routes` Edges whose `dst` is the (unresolved) controller constant a route
  # points at. Resolution to a real controller node — and dropping routes to
  # controllers not in the repo — is Extractor's job, same as every other edge.
  #
  # Static only: we mirror Rails' own routing conventions (a `to: 'a/b#c'` maps
  # to `A::BController`; `namespace`/`scope module:` prefix the module;
  # `resources`/`resource` name a pluralized controller) rather than booting the
  # app for `rails routes`. So the long tail — constraints, mounted engines,
  # `concern`s, implicit-controller `verb 'path'` — is under-reported, not lied
  # about, consistent with the rest of lupa.
  class RouteWalker < Prism::Visitor
    HTTP_METHODS = %w[get post put patch delete match].freeze

    attr_reader :nodes, :edges

    def initialize(file:)
      @file = file
      @nodes = []
      @edges = []
      @module_stack = [] # controller-const prefix, from namespace / scope module:
      @path_stack = []   # route-label prefix, from namespace / scope path
      super()
    end

    # Routes declare no model associations; kept so every walker answers the
    # same messages (nodes / edges / associations) for Extractor.
    def associations = []

    def visit_call_node(node)
      case node.name.to_s
      when "namespace"      then with_namespace(node) { super }
      when "scope"          then with_scope(node) { super }
      when "devise_for"     then record_devise(node); super
      when "resources", "resource" then record_resource(node); super
      when *HTTP_METHODS    then record_verb(node, node.name.to_s); super
      else super
      end
    end

    private

    # namespace :admin -> module "Admin" AND path "admin".
    def with_namespace(node)
      seg = first_literal(node)
      push(camelize(seg), seg) { yield }
    end

    # scope module: :admin -> module only (a positional scope is a path prefix,
    # which affects the label but not the controller constant we care about).
    def with_scope(node)
      mod = string_value(keyword_args(node)["module"])
      push(mod && camelize(mod), nil) { yield }
    end

    def push(mod, path)
      @module_stack.push(mod) if mod
      @path_stack.push(path) if path
      yield
    ensure
      @module_stack.pop if mod
      @path_stack.pop if path
    end

    # get "p", to: "c#a" | get "p" => "c#a" (hash-rocket) | post "/p", to: "c#a"
    def record_verb(node, verb)
      args = node.arguments&.arguments || []
      if (to = string_value(keyword_args(node)["to"]))
        add_route(label(verb, string_value(args.first)), to, node)
      elsif (pair = rocket_pair(args))
        add_route(label(verb, pair.first), pair.last, node)
      end
    end

    # devise_for :patients, controllers: { registrations: "patients/registrations" }
    def record_devise(node)
      controllers = keyword_args(node)["controllers"]
      return unless hash_node?(controllers)

      scope = first_literal(node)
      each_assoc(controllers) do |role, value|
        target = string_value(value)
        add_route("DEVISE /#{scope}/#{role}", target, node) if target
      end
    end

    # resources :widgets | resource :profile | resources :x, controller: "y"
    def record_resource(node)
      name = first_literal(node)
      return unless name

      override = string_value(keyword_args(node)["controller"])
      controller = override || (node.name.to_s == "resource" ? pluralize(name) : name)
      add_route("#{node.name.to_s.upcase} /#{path_label(name)}", controller, node)
    end

    def add_route(label, target, node)
      controller = controller_const(target)
      return unless controller

      line = node.location.start_line
      @nodes << Node.new(label, "route", @file, line)
      @edges << Edge.new(label, "routes", controller, line)
    end

    # "patients/registrations#store" -> "Patients::RegistrationsController",
    # prefixed by the enclosing module scope unless the path is absolute (/...).
    def controller_const(target)
      path = target.to_s.split("#").first.to_s
      return if path.empty?

      segments = path.split("/").reject(&:empty?).map { |s| camelize(s) }
      prefix = path.start_with?("/") ? [] : @module_stack
      "#{(prefix + segments).join("::")}Controller"
    end

    def label(verb, path)
      "#{verb.upcase} /#{path_label(path)}"
    end

    def path_label(path)
      (@path_stack + [path.to_s.sub(%r{\A/}, "")]).reject(&:empty?).join("/")
    end

    def camelize(str)
      Inflector.camelize(str)
    end

    # Naive singular -> plural for `resource`; good enough for controller naming.
    def pluralize(str)
      s = str.to_s
      s.end_with?("s") ? s : "#{s}s"
    end

    def rocket_pair(args)
      each_assoc(args.last) do |key_node, value_node|
        k = string_value(key_node)
        v = string_value(value_node)
        return [k, v] if k && v && v.include?("#")
      end
      nil
    end

    # Symbol-keyed keyword args of a call, as { "key" => value_node }.
    def keyword_args(node)
      last = node.arguments&.arguments&.last
      return {} unless hash_node?(last)

      last.elements.each_with_object({}) do |el, acc|
        next unless el.is_a?(Prism::AssocNode) && el.key.is_a?(Prism::SymbolNode)

        acc[el.key.unescaped] = el.value
      end
    end

    def each_assoc(hash)
      return unless hash_node?(hash)

      hash.elements.each do |el|
        next unless el.is_a?(Prism::AssocNode)

        key = el.key.is_a?(Prism::SymbolNode) ? el.key.unescaped : el.key
        yield key, el.value
      end
    end

    def hash_node?(node)
      node.is_a?(Prism::KeywordHashNode) || node.is_a?(Prism::HashNode)
    end

    def first_literal(node)
      arg = node.arguments&.arguments&.first
      arg.unescaped if arg.is_a?(Prism::SymbolNode) || arg.is_a?(Prism::StringNode)
    end

    def string_value(node)
      node.unescaped if node.is_a?(Prism::StringNode) || node.is_a?(Prism::SymbolNode)
    end
  end
end
