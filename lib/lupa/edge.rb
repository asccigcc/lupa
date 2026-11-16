# frozen_string_literal: true

module Lupa
  # A relationship between two constants. Walker fills `dst` with the raw,
  # unresolved constant string; Resolver rewrites it to a resolved node name
  # (or drops the edge if it can't be resolved within the repo).
  #
  # `nesting` is the lexical scope at the reference (see Scope#nesting). It only
  # feeds resolution; resolved edges carry an empty one.
  #
  # `file` is where the edge was found — not necessarily the file defining
  # `src`, since a class can be reopened elsewhere.
  #
  # `message` is the instance method a `sends` edge calls; nil on every other rel.
  Edge = Data.define(:src, :rel, :dst, :file, :line, :nesting, :message) do
    def initialize(src:, rel:, dst:, file:, line:, nesting: [], message: nil)
      super
    end
  end
end
