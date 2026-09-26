# frozen_string_literal: true

require "prism"

module Lupa
  # Read-only helpers over Prism nodes, shared by every walker and recognizer.
  # All of lupa's knowledge of Prism node *types* lives here, so the rest of
  # the code asks questions ("is this a constant?") instead of checking classes.
  module Ast
    CONSTANTS = [Prism::ConstantReadNode, Prism::ConstantPathNode].freeze
    LITERALS  = [Prism::StringNode, Prism::SymbolNode].freeze
    HASHES    = [Prism::KeywordHashNode, Prism::HashNode].freeze

    module_function

    # @return [Boolean] whether node is a constant reference (Foo or Foo::Bar)
    def constant?(node)
      CONSTANTS.any? { |type| node.is_a?(type) }
    end

    # @return [String, nil] dotted constant path, e.g. "Api::FooController"
    def const_string(node)
      case node
      when Prism::ConstantReadNode then node.name.to_s
      when Prism::ConstantPathNode then [const_string(node.parent), node.name].compact.join("::")
      end
    end

    # @return [String, nil] the text of a string or symbol literal
    def literal(node)
      node.unescaped if LITERALS.any? { |type| node.is_a?(type) }
    end

    # @return [Boolean] whether node is a hash or keyword-hash literal
    def hash?(node)
      HASHES.any? { |type| node.is_a?(type) }
    end

    # @return [Boolean] whether node is the literal `true`
    def true?(node)
      node.is_a?(Prism::TrueNode)
    end

    # @return [Boolean] whether node is a method call (a receiver like `x.orders`)
    def call?(node)
      node.is_a?(Prism::CallNode)
    end

    # @return [Array<Prism::Node>] positional + keyword argument nodes of a call
    def args(node)
      node.arguments&.arguments || []
    end

    # @return [String, nil] the first argument, when it is a string/symbol literal
    def first_literal(node)
      literal(args(node).first)
    end

    # @return [Array<String>] positional symbol arguments (`after_save :a, :b, if: :c` -> a, b)
    def symbols(node)
      args(node).grep(Prism::SymbolNode).map(&:unescaped)
    end

    # @return [Array<String>] constant arguments (`include A, B::C` -> A, B::C)
    def constants(node)
      args(node).filter_map { |arg| const_string(arg) }
    end

    # @return [Hash{String => Prism::Node}] symbol-keyed options of a call
    def keyword_args(node)
      each_pair(args(node).last).select { |key, _| key.is_a?(String) }.to_h
    end

    # @return [Enumerator<[String | Prism::Node, Prism::Node]>] a hash literal's pairs,
    #   symbol keys unwrapped to their name, other keys left as nodes
    def each_pair(hash)
      return enum_for(__method__, hash) unless block_given?
      return unless hash?(hash)

      hash.elements.grep(Prism::AssocNode).each { |el| yield pair_key(el.key), el.value }
    end

    def pair_key(key)
      key.is_a?(Prism::SymbolNode) ? key.unescaped : key
    end
  end
end
