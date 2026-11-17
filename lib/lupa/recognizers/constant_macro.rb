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

        Ast.constants(node).each { |const| record(node, rel, const, recorder) }
        true
      end

      # An included or prepended module's instance methods answer calls on the
      # class too, which is what lets a `sends` be checked against them.
      def record(node, rel, const, recorder)
        recorder.add(node, rel, const)
        recorder.mix(const) if Vocabulary::INSTANCE_MIXINS.include?(node.name.to_s)
      end
    end
  end
end
