# frozen_string_literal: true

module Lupa
  # Per-file accumulator that a Walker and its recognizers write into: the
  # nodes defined, the raw edges found (sourced at the current scope), the
  # association-name pairs that feed Resolver's `persists` index, and the
  # instance methods and mixins that let it check a `sends`.
  class Recorder
    attr_reader :nodes, :edges, :associations, :declarations, :method_defs, :mixins

    # @param scope [Scope] supplies the `src` and `file` of every node and edge
    def initialize(scope)
      @scope = scope
      @nodes, @edges, @associations, @declarations, @method_defs, @mixins = Array.new(6) { [] }
      @consumed = Set.new.compare_by_identity
    end

    # @return [String] the class/module the scope is currently inside
    def current = scope.current

    # Records what an integration found, for the app-wide picture assembled
    # after the walk (see Integrations).
    def declare(found)
      declarations << found
    end

    # Records the class/module the scope is currently inside.
    def define(kind, line)
      nodes << Node.new(scope.current, kind, scope.file, line)
    end

    # @param nesting [Array<String>] lexical scope dst is looked up in
    # @return [true] so a recognizer can end with it to claim the call
    def add(node, rel, dst, nesting: scope.nesting)
      edges << build(node, rel, dst, nesting)
      true
    end

    # @param accessor [String] what the receiver was read through, e.g. "current_patient"
    # @param message [String] the instance method sent to it
    # @return [true]
    def add_message(node, accessor, message)
      edges << build(node, "sends", accessor, scope.nesting).with(message:)
      true
    end

    # @param name [String] an association accessor, e.g. "orders"
    # @param target [String] the raw constant it points at, e.g. "Order"
    # @param singular [Boolean] whether it returns one record (belongs_to, has_one)
    def associate(name, target, singular: false)
      associations << [name, target, scope.current, singular]
    end

    # @param name [String] an instance method defined in the current class/module
    def defines(name)
      method_defs << [scope.current, name]
    end

    # @param const [String] a module the current class includes or prepends, raw
    def mix(const)
      mixins << [scope.current, const, scope.nesting]
    end

    # Marks a call node already represented by an enclosing edge (the `.welcome`
    # behind `.deliver_later`). Prism visits the outer call before descending
    # into its receiver, so the mark is always set before the inner call is seen.
    def consume(node)
      consumed.add(node)
    end

    # @return [Boolean] whether node was consumed (clearing the mark)
    def consumed?(node)
      !consumed.delete?(node).nil?
    end

    private

    attr_reader :scope, :consumed

    def build(node, rel, dst, nesting)
      Edge.new(src: scope.current, rel:, dst:, file: scope.file, line: node.location.start_line, nesting:)
    end
  end
end
