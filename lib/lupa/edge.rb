# frozen_string_literal: true

module Lupa
  # A relationship between two constants. Walker fills `dst` with the raw,
  # unresolved constant string; Resolver rewrites it to a resolved node name
  # (or drops the edge if it can't be resolved within the repo).
  #
  # `nesting` is the lexical scope at the reference (see Scope#nesting). It only
  # feeds resolution; resolved edges carry an empty one.
  Edge = Data.define(:src, :rel, :dst, :line, :nesting) do
    def initialize(src:, rel:, dst:, line:, nesting: [])
      super
    end
  end
end
