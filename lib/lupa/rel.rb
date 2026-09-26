# frozen_string_literal: true

module Lupa
  # How Resolver turns each rel's raw `dst` into its final value:
  #
  # - :marker   — dst is not a node (runtime code, a same-class method name);
  #               kept verbatim as a signpost.
  # - :model    — a write; dst is a model constant or an association accessor,
  #               and the edge survives only if it lands on a model.
  # - :constant — everything else; a constant resolved within the repo.
  module Rel
    RESOLUTION = { "dispatches" => :marker, "triggers" => :marker, "persists" => :model }.freeze

    module_function

    # @param rel [String] e.g. "calls"
    # @return [Symbol] :marker, :model or :constant
    def resolution(rel)
      RESOLUTION.fetch(rel, :constant)
    end
  end
end
