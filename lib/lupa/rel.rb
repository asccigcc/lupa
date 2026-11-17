# frozen_string_literal: true

module Lupa
  # How Resolver turns each rel's raw `dst` into its final value:
  #
  # - :marker   — dst is not a node (runtime code, a same-class method name);
  #               kept verbatim as a signpost.
  # - :model    — dst is a model constant or a name that denotes one (an
  #               association accessor, a gem-generated helper); the edge
  #               survives only if it lands on a model.
  # - :superclass — a constant read before the class being defined exists.
  # - :association — a constant looked up from the owning class's name, as Rails does.
  # - :route    — a controller Rails names in full; an exact match or nothing.
  # - :message  — dst is a singular accessor (`current_patient`, a belongs_to);
  #               kept only when it returns one model that defines the method
  #               the edge sends.
  # - :constant — everything else; a constant resolved in its lexical scope.
  module Rel
    RESOLUTION = {
      "dispatches" => :marker, "triggers" => :marker,
      "persists" => :model, "authenticates" => :model, "association" => :association,
      "inherits" => :superclass,
      "routes" => :route,
      "sends" => :message
    }.freeze

    # Their dst is never a node, so no chain continues from one.
    MARKERS = %w[dispatches triggers].freeze

    # "Has a" and "must be signed in as": true of a class, but no code runs
    # along them, so a call chain stepping through one is not a chain at all.
    STRUCTURAL = %w[association authenticates].freeze

    module_function

    # @param rel [String] e.g. "calls"
    # @return [Symbol] :marker, :model, :superclass, :association, :route, :message or :constant
    def resolution(rel)
      RESOLUTION.fetch(rel, :constant)
    end
  end
end
