# frozen_string_literal: true

module Lupa
  module Recognizers
    # An ActiveRecord write on a model constant (`Order.create!`) or through an
    # association proxy (`patient.orders.create!`) -> `persists`. The dst is the
    # constant, or the accessor name that Resolver maps via the association index.
    module Persist
      module_function

      # @return [Boolean] whether the call was recognized (and recorded)
      def call(node, recorder)
        return false unless Vocabulary::PERSIST.include?(node.name.to_s)

        target = target_for(node.receiver)
        target ? recorder.add(node, "persists", target) : false
      end

      # Only a method-call receiver counts as an accessor: a bare local
      # (`rec.save`) that shares an association's name is not that model.
      def target_for(recv)
        return Ast.const_string(recv) if Ast.constant?(recv)

        recv.name.to_s if Ast.call?(recv)
      end
    end
  end
end
