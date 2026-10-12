# frozen_string_literal: true

module Lupa
  module Integrations
    module Devise
      # `devise_for :patients, controllers: { sessions: "patients/sessions" }`.
      #
      # This is the *only* place a scope comes from. `devise_for` is what calls
      # `Devise.add_mapping`, and the mapping is what names every helper, so a
      # model's own `devise` call declares nothing — it just includes modules.
      # Reading a scope off the model instead would invent helpers the app does
      # not have: `devise_for :members, class_name: "User"` generates
      # `current_member`, never `current_user`.
      #
      # The mount is also expanded into the routes Devise generates for it, so
      # `/sign_in` is searchable as the path it really is. Only the
      # `controllers:` overrides are expanded: Devise's own controllers live in
      # the gem, so a role without an override has no class here to point at.
      module Mount
        # Devise builds these paths from the model's `omniauth_providers`, which
        # a routes file cannot see. Only the prefix is knowable, so the
        # controller keeps a marker rather than an invented URL.
        OMNIAUTH = "omniauth_callbacks"

        module_function

        # @return [Boolean] whether the call was recognized (and recorded)
        def call(node, recorder)
          return false unless node.name == :devise_for

          mount(Ast.first_literal(node).to_s, Ast.keyword_args(node), node, recorder)
          true
        end

        # @param name [String] the plural name the mount is declared with, e.g. "patients"
        def mount(name, options, node, recorder)
          recorder.declare(scope_for(name, options))
          expand(Mounted.new(name, options), node, recorder)
        end

        def expand(mounted, node, recorder)
          mounted.controllers.each do |role, target|
            routes(role, target, mounted).each { |route| recorder.record(route, node) }
          end
        end

        # @return [Array<Route>] the routes one role contributes
        def routes(role, target, mounted)
          return [marker(target, mounted)] if role == OMNIAUTH

          Routes.expand(role, mounted.path_names).map do |verb, suffix, action|
            Route.new(verb:, path: join(mounted.base, suffix), target: "#{target}##{action}")
          end
        end

        def marker(target, mounted)
          Route.new(verb: "DEVISE", path: join(mounted.base, "auth"), target:)
        end

        def join(*segments) = segments.reject { |segment| segment.to_s.empty? }.join("/")

        # `devise_for` is plural, the scope Devise derives from it singular.
        def scope_for(name, options)
          scope = Inflector.singularize(name)
          model = Ast.literal(options["class_name"]) || Inflector.camelize(scope)
          Scope.new(name: scope, model:)
        end
      end
    end
  end
end
