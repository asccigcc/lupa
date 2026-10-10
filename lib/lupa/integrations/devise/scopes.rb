# frozen_string_literal: true

module Lupa
  module Integrations
    module Devise
      # `devise :database_authenticatable, :confirmable` in a model. The model
      # is the class being defined, which is what makes the scope's accessors
      # resolvable; the modules are kept because the default routes depend on
      # them. A model may call it more than once (a two-factor setup usually
      # does), so each call declares and the scopes are unioned app-wide.
      module Scopes
        module_function

        # @return [Boolean] whether the call was recognized (and declared)
        def call(node, recorder)
          return false unless node.name == :devise && node.receiver.nil?

          recorder.declare(scope_for(node, recorder.current))
          true
        end

        def scope_for(node, model)
          name = Inflector.underscore(model.split("::").last)
          Scope.new(name:, model:, modules: Ast.symbols(node))
        end
      end
    end
  end
end
