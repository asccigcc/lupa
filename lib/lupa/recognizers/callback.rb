# frozen_string_literal: true

module Lupa
  module Recognizers
    # `after_create_commit :notify` -> a `triggers` marker whose dst is the
    # same-class method name (not a node). Only positional symbols count, so
    # `if:`/`unless:` option values and block callbacks are never recorded.
    module Callback
      module_function

      # @return [Boolean] whether the call was recognized (and recorded)
      def call(node, recorder)
        return false unless Vocabulary::CALLBACKS.include?(node.name.to_s)

        Ast.symbols(node).each { |method| recorder.add(node, "triggers", method) }
        true
      end
    end
  end
end
