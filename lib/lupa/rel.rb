# frozen_string_literal: true

module Lupa
  # How Resolver turns each rel's raw `dst` into its final value:
  #
  # - :marker   — dst is not a node (runtime code, a same-class method name);
  #               kept verbatim as a signpost.
  # - :model    — a write; dst is a model constant or an association accessor,
  #               and the edge survives only if it lands on a model.
  # - :superclass — a constant read before the class being defined exists.
  # - :association — a constant looked up from the owning class's name, as Rails does.
  # - :constant — everything else; a constant resolved in its lexical scope.
  module Rel
    RESOLUTION = {
      "dispatches" => :marker, "triggers" => :marker, "persists" => :model, "association" => :association,
      "inherits" => :superclass
    }.freeze

    module_function

    # @param rel [String] e.g. "calls"
    # @return [Symbol] :marker, :model, :superclass, :association or :constant
    def resolution(rel)
      RESOLUTION.fetch(rel, :constant)
    end
  end
end
