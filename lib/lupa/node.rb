# frozen_string_literal: true

module Lupa
  # A defined class/module. `name` is the fully-qualified constant path.
  Node = Struct.new(:name, :kind, :file, :line)
end
