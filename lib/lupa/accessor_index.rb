# frozen_string_literal: true

module Lupa
  # Maps an accessor name to the model it returns, app-wide, so
  # `x.orders.create!` resolves without typing `x`. Two populations feed it:
  # the app's own associations (`orders` -> Order) and the accessors its gems
  # generate (`current_patient` -> Patient, see Integrations). A name declared
  # with conflicting targets across the app (`child` => both Message and
  # Delivery) resolves to nil rather than a guess.
  class AccessorIndex
    # @param pairs [Array<(String, String, String, Boolean)>] [accessor name, raw target,
    #   owner, singular]; a missing singular flag means a collection
    # @param consts [ConstIndex] resolves each raw target from its owner's namespace
    def initialize(pairs, consts)
      named = pairs.group_by(&:first)
      @targets = named.transform_values do |group|
        group.filter_map { |_, raw, owner| consts.resolve(raw, Resolver.owner_nesting(owner)) }.uniq
      end
      @singular = named.select { |_, group| group.all? { |pair| pair[3] } }.keys.to_set
    end

    # @param name [String] an accessor name, e.g. "orders"
    # @return [String, nil] the unique model it targets
    def resolve(name)
      candidates = targets.fetch(name, [])
      candidates.first if candidates.one?
    end

    # A name counts only if every declaration of it returns one record.
    # @param name [String] e.g. "current_patient", "patient"
    # @return [String, nil] the unique model the accessor returns a record of
    def resolve_record(name)
      resolve(name) if singular.include?(name)
    end

    private

    attr_reader :targets, :singular
  end
end
