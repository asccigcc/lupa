# frozen_string_literal: true

module Lupa
  # The class/module definitions a walker is inside, as Ruby sees them.
  # `nesting` mirrors `Module.nesting` (innermost first): `module A; class B`
  # puts both A::B and A in scope, but compact `class A::B` puts only A::B.
  # Both readers are cached because they're read once per call node.
  class Scope
    attr_reader :current, :nesting

    def initialize
      @frames = []
      refresh
    end

    # @param name [String] a (possibly dotted or root-anchored) constant name
    # @yield while `name` is the innermost scope
    def within(name)
      frames.push(qualify(name))
      refresh
      yield
      frames.pop
      refresh
    end

    # @return [Boolean] true at top level, outside any class/module
    def empty?
      frames.empty?
    end

    private

    attr_reader :frames

    def qualify(name)
      return name.delete_prefix("::") if name.start_with?("::") || empty?

      "#{current}::#{name}"
    end

    def refresh
      @current = frames.last || ""
      @nesting = frames.reverse.freeze
    end
  end
end
