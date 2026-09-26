# frozen_string_literal: true

module Lupa
  # A defined class/module (or a route). `name` is the fully-qualified constant path.
  Node = Data.define(:name, :kind, :file, :line)
end
