# frozen_string_literal: true

module Lupa
  # Resolves a raw constant string to a node defined in the repo: an exact
  # full-name match wins, else a *unique* short name. Ambiguous or unknown
  # constants resolve to nil — dropped, never guessed.
  class ConstIndex
    # @param nodes [Array<Node>] unique by name
    def initialize(nodes)
      @by_full = nodes.to_h { |node| [node.name, node] }
      @by_short = nodes.map(&:name).group_by { |name| short(name) }
    end

    # @param const [String] e.g. "Order" or "Api::OrdersController"
    # @return [String, nil] the resolved node name
    def resolve(const)
      return const if by_full.key?(const)

      candidates = by_short.fetch(short(const), [])
      candidates.first if candidates.one?
    end

    # @return [Boolean] whether name is a node of kind model
    def model?(name)
      by_full[name]&.kind == "model"
    end

    private

    attr_reader :by_full, :by_short

    def short(name)
      name.split("::").last
    end
  end
end
