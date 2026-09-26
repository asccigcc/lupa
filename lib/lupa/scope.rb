# frozen_string_literal: true

module Lupa
  # The stack of class/module names a walker is inside, e.g. ["Api", "Foo"].
  # `current` is cached on every push/pop because it's read once per call node.
  class Scope
    attr_reader :current

    def initialize
      @names = []
      @current = ""
    end

    # @param name [String] a (possibly dotted) constant name
    # @yield while `name` is the innermost scope
    def within(name)
      names.push(name)
      refresh
      yield
      names.pop
      refresh
    end

    # @return [Boolean] true at top level, outside any class/module
    def empty?
      names.empty?
    end

    private

    attr_reader :names

    def refresh
      @current = names.join("::")
    end
  end
end
