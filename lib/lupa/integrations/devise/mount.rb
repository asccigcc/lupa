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
      # Only the `controllers:` overrides point into the app, so only they are
      # recorded as routes; Devise's own default routes are handled elsewhere,
      # since expanding them needs the model's modules from another file.
      module Mount
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
          Ast.each_pair(options["controllers"]) do |role, value|
            recorder.record(Route.new(verb: "DEVISE", path: "#{name}/#{role}", target: Ast.literal(value)), node)
          end
        end

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
