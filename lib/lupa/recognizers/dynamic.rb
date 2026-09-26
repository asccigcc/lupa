# frozen_string_literal: true

module Lupa
  module Recognizers
    # `expr.constantize` / `expr.safe_constantize` — the target is computed at
    # runtime, so it can't be resolved. Record a `dispatches` marker keyed on the
    # receiver's source so the chain forks visibly instead of ending silently.
    module Dynamic
      LABEL_LIMIT = 80

      module_function

      # @return [Boolean] whether the call was recognized (and recorded)
      def call(node, recorder)
        return false unless Vocabulary::DYNAMIC.include?(node.name.to_s) && node.receiver

        recorder.add(node, "dispatches", node.receiver.slice.gsub(/\s+/, " ")[0, LABEL_LIMIT])
      end
    end
  end
end
