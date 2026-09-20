# frozen_string_literal: true

require "prism"
require_relative "graph"

module Lupa
  # Visits one parsed file, collecting Nodes (class/module definitions) and raw
  # Edges whose `dst` is still an unresolved constant string. Resolution to real
  # node names is Extractor's job.
  class Walker < Prism::Visitor
    CALL_METHODS    = %w[call call!].freeze
    ENQUEUE_METHODS = %w[perform_later perform_async perform_now perform_in perform_at].freeze
    ASSOCIATIONS    = %w[has_many has_one belongs_to has_and_belongs_to_many].freeze

    attr_reader :nodes, :edges

    def initialize(file:, kind:)
      @file = file
      @kind = kind
      @nodes = []
      @edges = []
      @scope = []
      super()
    end

    # Dotted string for a constant node, e.g. "Api::FooController".
    def self.const_string(node)
      case node
      when Prism::ConstantReadNode then node.name.to_s
      when Prism::ConstantPathNode
        [const_string(node.parent), node.name].compact.join("::")
      end
    end

    # Rough Rails classify: :chart_notes -> "ChartNote".
    def self.classify(sym)
      singular = sym.to_s.sub(/s\z/, "")
      singular.split("_").map(&:capitalize).join
    end

    def visit_module_node(node)
      @scope.push(self.class.const_string(node.constant_path))
      mkind = @file.include?("/concerns/") ? "concern" : "module"
      @nodes << Node.new(current, mkind, @file, node.location.start_line)
      super
      @scope.pop
    end

    def visit_class_node(node)
      @scope.push(self.class.const_string(node.constant_path))
      @nodes << Node.new(current, @kind, @file, node.location.start_line)
      if (sc = node.superclass) && (s = self.class.const_string(sc))
        @edges << Edge.new(current, "inherits", s, sc.location.start_line)
      end
      super
      @scope.pop
    end

    def visit_call_node(node)
      record_call(node)
      super
    end

    private

    def current
      @scope.join("::")
    end

    def record_call(node)
      return if current.empty?

      name = node.name.to_s
      return if macro_edge(node, name)

      handoff_edge(node, name)
    end

    # include/organize/association macros — targets come from the arguments.
    def macro_edge(node, name)
      if %w[include prepend extend].include?(name)
        each_const_arg(node) { |c| add(node, "includes", c) }
      elsif name == "organize"
        each_const_arg(node) { |c| add(node, "organizes", c) }
      elsif ASSOCIATIONS.include?(name)
        sym = first_symbol_arg(node)
        add(node, "association", self.class.classify(sym)) if sym
      else
        return false
      end
      true
    end

    # Const.call / Const.perform_later — target is the receiver constant.
    def handoff_edge(node, name)
      recv = node.receiver
      return unless recv.is_a?(Prism::ConstantReadNode) || recv.is_a?(Prism::ConstantPathNode)

      rel =
        if CALL_METHODS.include?(name) then "calls"
        elsif ENQUEUE_METHODS.include?(name) then "enqueues"
        end
      add(node, rel, self.class.const_string(recv)) if rel
    end

    def add(node, rel, const)
      @edges << Edge.new(current, rel, const, node.location.start_line)
    end

    def each_const_arg(node)
      node.arguments&.arguments&.each do |arg|
        c = self.class.const_string(arg)
        yield c if c
      end
    end

    def first_symbol_arg(node)
      arg = node.arguments&.arguments&.first
      arg.unescaped.to_sym if arg.is_a?(Prism::SymbolNode)
    end
  end
end
