# frozen_string_literal: true

module Lupa
  # Resolves a raw constant string to a node defined in the repo, following
  # Ruby's lookup: a root-anchored `::X` is top-level only; otherwise the first
  # segment binds in the first scope that defines it (enclosing namespaces,
  # then ancestors — see Hierarchy#scopes), then at the top level. Failing
  # both, a *unique* short name is accepted. Ambiguous or unknown constants
  # resolve to nil — dropped, never guessed.
  class ConstIndex
    # @param nodes [Array<Node>] unique by name
    def initialize(nodes)
      @by_full = nodes.to_h { |node| [node.name, node] }
      @by_short = nodes.map(&:name).group_by { |name| short(name) }
      @namespaces = nodes.flat_map { |node| prefixes(node.name) }.to_set
    end

    # @param const [String] e.g. "Order", "Api::OrdersController" or "::Order"
    # @param nesting [Array<String>] scopes to search, in lookup order
    # @param defining [String, nil] a class whose superclass is being read; it
    #   doesn't exist yet at that point, so it can never be the answer
    # @return [String, nil] the resolved node name
    def resolve(const, nesting = [], defining: nil)
      return exact(const.delete_prefix("::")) if const.start_with?("::")

      cref = lexical_cref(const.split("::").first, nesting, defining)
      target = cref ? exact("#{cref}::#{const}") : exact(const) || unique(const)
      target unless target == defining
    end

    # @return [Boolean] whether name is a node of kind model
    def model?(name)
      by_full[name]&.kind == "model"
    end

    private

    attr_reader :by_full, :by_short, :namespaces

    # The innermost namespace in which const's first segment is defined.
    def lexical_cref(head, nesting, defining)
      nesting.find { |cref| namespaces.include?("#{cref}::#{head}") && "#{cref}::#{head}" != defining }
    end

    def exact(name)
      name if by_full.key?(name)
    end

    def unique(const)
      candidates = by_short.fetch(short(const), [])
      candidates.first if candidates.one?
    end

    def short(name)
      name.split("::").last
    end

    # "A::B::C" -> ["A", "A::B", "A::B::C"]
    def prefixes(name)
      parts = name.split("::")
      parts.each_index.map { |i| parts[0..i].join("::") }
    end
  end
end
