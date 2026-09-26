# frozen_string_literal: true

module Lupa
  module Recognizers
    # Class-body macros whose arguments are constants: `include Trackable`
    # (`includes`) and Interactor `organize StepA, StepB` (`organizes`).
    module ConstantMacro
      RELS = Vocabulary::MIXINS.to_h { |macro| [macro, "includes"] }.merge("organize" => "organizes").freeze

      module_function

      # @return [Boolean] whether the call was recognized (and recorded)
      def call(node, recorder)
        rel = RELS[node.name.to_s]
        return false unless rel

        Ast.constants(node).each { |const| recorder.add(node, rel, const) }
        true
      end
    end
  end
end
