# frozen_string_literal: true

require "forwardable"
require "prism"

module Lupa
  # Visits one parsed file, collecting Nodes (class/module definitions) and raw
  # Edges whose `dst` is still an unresolved constant string. Each call node is
  # offered to the recognizers in order; the first to claim it records its edge.
  # Resolution to real node names is Resolver's job.
  class Walker < Prism::Visitor
    extend Forwardable

    # Order matters: specific shapes (a mailer send, a write) must claim a call
    # before the generic Handoff fallback would record it as `invokes`.
    RECOGNIZERS = [
      Recognizers::Mailer, Recognizers::Dynamic, Recognizers::ConstantMacro,
      Recognizers::Association, Recognizers::Callback, Recognizers::Persist,
      Recognizers::Handoff
    ].freeze

    def_delegators :recorder, :nodes, :edges, :associations

    # @param file [String] repo-relative path, stored on every node
    # @param kind [Kind] decides the kind of the classes/modules defined here
    def initialize(file:, kind: Kind.new(file))
      super()
      @kind = kind
      @scope = Scope.new(file)
      @recorder = Recorder.new(scope)
    end

    def visit_module_node(node)
      define(node, kind.for_module) { super }
    end

    def visit_class_node(node)
      define(node, kind.for_class) do
        record_superclass(node.superclass)
        super
      end
    end

    def visit_call_node(node)
      record_call(node)
      super
    end

    private

    attr_reader :kind, :scope, :recorder

    def define(node, node_kind)
      scope.within(Ast.const_string(node.constant_path)) do
        recorder.define(node_kind, node.location.start_line)
        yield
      end
    end

    # Ruby evaluates the superclass outside the class being opened.
    def record_superclass(superclass)
      parent = Ast.const_string(superclass)
      recorder.add(superclass, "inherits", parent, nesting: scope.nesting.drop(1)) if parent
    end

    def record_call(node)
      return if scope.empty? || recorder.consumed?(node)

      RECOGNIZERS.any? { |recognizer| recognizer.call(node, recorder) }
    end
  end
end
