# frozen_string_literal: true

module Lupa
  # Which instance methods a class answers through code in the repo: its own
  # `def`s, those of the modules it includes or prepends, and those of its
  # superclasses, followed transitively. A method that arrives any other way
  # (`delegate`, `attr_*`, a column, `define_method`, a gem) is unknown here,
  # so a `sends` relying on it is dropped rather than guessed.
  #
  #   index = MethodIndex.new([["Patient", "cancel!"]], [], hierarchy, consts)
  #   index.defines?("Patient", "cancel!") # => true
  class MethodIndex
    # @param defs [Array<(String, String)>] [owner, instance method name]
    # @param mixins [Array<(String, String, Array<String>)>] [owner, raw module, nesting]
    # @param hierarchy [Hierarchy] resolves each class's superclass
    # @param consts [ConstIndex] resolves each mixed-in module from its nesting
    def initialize(defs, mixins, hierarchy, consts)
      @own = defs.group_by(&:first).transform_values { |pairs| pairs.to_set(&:last) }
      @modules = resolve_mixins(mixins, hierarchy, consts)
      @hierarchy = hierarchy
    end

    # @param owner [String] a resolved class or module name
    # @param name [String] an instance method name
    # @return [Boolean] whether owner, or anything it includes or inherits, defines name
    def defines?(owner, name)
      lineage(owner).any? { |klass| own.fetch(klass, EMPTY).include?(name) }
    end

    EMPTY = Set.new.freeze
    private_constant :EMPTY

    private

    attr_reader :own, :modules, :hierarchy

    # owner, then every module and superclass reachable from it, each once.
    def lineage(name, seen = Set.new)
      return [] unless seen.add?(name)

      parents = modules.fetch(name, []) + [hierarchy.superclass(name)].compact
      [name, *parents.flat_map { |parent| lineage(parent, seen) }]
    end

    def resolve_mixins(mixins, hierarchy, consts)
      mixins.each_with_object(Hash.new { |hash, owner| hash[owner] = [] }) do |(owner, raw, nesting), index|
        target = consts.resolve(raw, hierarchy.scopes(nesting))
        index[owner] << target if target
      end
    end
  end
end
