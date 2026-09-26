# frozen_string_literal: true

module Lupa
  module Recognizers
    # `SomeMailer.action(...).deliver_later/deliver_now` -> `emails` the mailer.
    # Every call in the receiver chain (`.with`, `.action`) is consumed so none
    # also surfaces as a redundant `invokes` on the same expression.
    module Mailer
      module_function

      # @return [Boolean] whether the call was recognized (and recorded)
      def call(node, recorder)
        return false unless Vocabulary::DELIVER.include?(node.name.to_s)

        mailer = root_constant(node.receiver)
        return false unless mailer

        consume_chain(node.receiver, recorder)
        recorder.add(node, "emails", mailer)
      end

      def consume_chain(recv, recorder)
        return unless Ast.call?(recv)

        recorder.consume(recv)
        consume_chain(recv.receiver, recorder)
      end

      # The constant a send chain roots at, unwrapping `.action` / `.with` calls.
      def root_constant(recv)
        return Ast.const_string(recv) if Ast.constant?(recv)

        root_constant(recv.receiver) if Ast.call?(recv)
      end
    end
  end
end
