# frozen_string_literal: true

module Lupa
  module Integrations
    module Devise
      # `before_action :authenticate_patient!` -> an `authenticates` edge to the
      # model that scope authenticates, answering "what must be signed in to
      # reach this controller?".
      #
      # `skip_before_action` is deliberately not a filter here: it exempts
      # actions from a filter declared elsewhere, so reading it as a requirement
      # would state the opposite of what the controller says.
      #
      # The dst is the helper name verbatim. It resolves only if a `devise_for`
      # declared that scope, so the lookalikes a real app is full of —
      # `authenticate_csv!`, or `authenticate_user!` in an app with no User —
      # drop instead of inventing a model.
      module Authenticate
        HELPER = /\Aauthenticate_\w+!\z/

        module_function

        # @return [Boolean] whether the call was recognized (and recorded)
        def call(node, recorder)
          return false unless Vocabulary::FILTERS.include?(node.name.to_s)

          helpers = Ast.symbols(node).grep(HELPER)
          helpers.each { |helper| recorder.add(node, "authenticates", helper) }
          helpers.any?
        end
      end
    end
  end
end
