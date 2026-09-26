# frozen_string_literal: true

module Lupa
  module Recognizers
    # `has_many` / `has_one` / `belongs_to` / `habtm` -> an `association` edge,
    # plus an accessor-name pair (`orders` -> Order) for the `persists` index.
    module Association
      module_function

      # @return [Boolean] whether the call was recognized (recorded when resolvable)
      def call(node, recorder)
        macro = node.name.to_s
        return false unless Vocabulary::ASSOCIATIONS.include?(macro)

        target = target_for(node, macro)
        record(node, target, recorder) if target
        true
      end

      def record(node, target, recorder)
        recorder.add(node, "association", target)
        name = Ast.first_literal(node)
        recorder.associate(name, target) if name
      end

      # An explicit `class_name:` wins over the naming convention (that guess is
      # wrong whenever the two differ). `polymorphic: true` has no single target,
      # so drop it rather than invent one.
      def target_for(node, macro)
        opts = Ast.keyword_args(node)
        return if Ast.true?(opts["polymorphic"])
        return Ast.literal(opts["class_name"]) if opts.key?("class_name")

        conventional_class(macro, Ast.first_literal(node))
      end

      # Rails singularizes only collection names; belongs_to/has_one names are
      # already singular, so `belongs_to :status` is Status, never "Statu".
      def conventional_class(macro, name)
        return unless name

        name = Inflector.singularize(name) if Vocabulary::COLLECTIONS.include?(macro)
        Inflector.camelize(name)
      end
    end
  end
end
