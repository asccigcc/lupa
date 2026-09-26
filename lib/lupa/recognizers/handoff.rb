# frozen_string_literal: true

module Lupa
  module Recognizers
    # `Const.<method>` — the fallback. `.call` is the interactor handoff
    # (`calls`), the perform_* family is `enqueues`, the ActiveRecord surface is
    # dropped as noise, and any other class method is a generic `invokes`.
    # Resolver later drops receivers that aren't repo constants (Time, Rails, …).
    module Handoff
      DEFAULT_REL = "invokes"
      RELS = {}.merge(
        Vocabulary::CALL.to_h { |name| [name, "calls"] },
        Vocabulary::ENQUEUE.to_h { |name| [name, "enqueues"] },
        Vocabulary::NOISY.to_h { |name| [name, nil] }
      ).freeze

      module_function

      # @return [Boolean] whether the call was recognized (and recorded)
      def call(node, recorder)
        return false unless Ast.constant?(node.receiver)

        rel = RELS.fetch(node.name.to_s, DEFAULT_REL)
        rel ? recorder.add(node, rel, Ast.const_string(node.receiver)) : false
      end
    end
  end
end
