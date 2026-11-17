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
    # before the generic Handoff fallback would record it as `invokes`. A gem's
    # vocabulary is the most specific shape of all, so integrations go first.
    RECOGNIZERS = [
      *Integrations.recognizers,
      Recognizers::Mailer, Recognizers::Dynamic, Recognizers::ConstantMacro,
      Recognizers::Association, Recognizers::Callback, Recognizers::Persist,
      Recognizers::Message, Recognizers::Handoff
    ].freeze

    def_delegators :recorder, :nodes, :edges, :associations, :declarations, :method_defs, :mixins

    # @param file [String] repo-relative path, stored on every node
    # @param kind [Kind] decides the kind of the classes/modules defined here
    def initialize(file:, kind: Kind.new(file))
      super()
      @kind = kind
      @scope = Scope.new(file)
      @recorder = Recorder.new(scope)
      @singleton_depth = 0
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
      Vocabulary::CLASS_METHOD_BLOCKS.include?(node.name.to_s) ? on_singleton { super } : super
    end

    # Instance methods only: a `sends` edge is a call on an instance, so a
    # class method that shares its name must never vouch for one.
    def visit_def_node(node)
      recorder.defines(node.name.to_s) if instance_method?(node)
      super
    end

    def visit_singleton_class_node(node)
      on_singleton { super }
    end

    private

    attr_reader :kind, :scope, :recorder, :singleton_depth

    def instance_method?(node)
      node.receiver.nil? && !scope.empty? && singleton_depth.zero?
    end

    # Inside `class << self` or `class_methods do`, a bare `def` is a class method.
    def on_singleton
      @singleton_depth += 1
      yield
    ensure
      @singleton_depth -= 1
    end

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
