# frozen_string_literal: true

module Lupa
  # Maps an accessor name to the model it returns, app-wide, so
  # `x.orders.create!` resolves without typing `x`. Two populations feed it:
  # the app's own associations (`orders` -> Order) and the accessors its gems
  # generate (`current_patient` -> Patient, see Integrations). A name declared
  # with conflicting targets across the app (`child` => both Message and
  # Delivery) resolves to nil rather than a guess.
  class AccessorIndex
    # @param pairs [Array<(String, String, String)>] [accessor name, raw target, owner]
    # @param consts [ConstIndex] resolves each raw target from its owner's namespace
    def initialize(pairs, consts)
      @targets = pairs.group_by(&:first).transform_values do |named|
        named.filter_map { |_, raw, owner| consts.resolve(raw, Resolver.owner_nesting(owner)) }.uniq
      end
    end

    # @param name [String] an accessor name, e.g. "orders"
    # @return [String, nil] the unique model it targets
    def resolve(name)
      candidates = targets.fetch(name, [])
      candidates.first if candidates.one?
    end

    private

    attr_reader :targets
  end
end
