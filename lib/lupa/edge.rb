# frozen_string_literal: true

module Lupa
  # A relationship between two constants. Walker fills `dst` with the raw,
  # unresolved constant string; Extractor rewrites it to a resolved node name
  # (or drops the edge if it can't be resolved within the repo).
  Edge = Struct.new(:src, :rel, :dst, :line)
end
