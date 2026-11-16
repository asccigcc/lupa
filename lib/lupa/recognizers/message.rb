# frozen_string_literal: true

module Lupa
  module Recognizers
    # `accessor.method` — an instance method sent to a record read through an
    # accessor: `current_patient.cancel_subscription`, `order.patient.notify!`
    # -> `sends`, with the method kept as the edge's message. The dst is the
    # accessor name; Resolver keeps the edge only when that accessor returns one
    # model and the model defines the method.
    #
    # A bare local (`patient = find_patient; patient.cancel`) has no type, so it
    # is never a receiver here, and the ActiveRecord surface is left to Persist
    # and to the noise it is.
    module Message
      module_function

      # @return [Boolean] whether the call was recognized (recorded when it may resolve)
      def call(node, recorder)
        accessor = accessor_name(node.receiver)
        return false unless accessor && !Vocabulary::NOISY.include?(node.name.to_s)

        recorder.add_message(node, accessor, node.name.to_s)
      end

      # A constructor's result is typed by Handoff and Persist instead.
      def accessor_name(recv)
        recv.name.to_s if Ast.call?(recv) && !Ast.constructor?(recv)
      end
    end
  end
end
