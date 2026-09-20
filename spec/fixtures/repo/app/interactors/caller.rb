# frozen_string_literal: true

# Calls a bare `Dup`, which is defined as both A::Dup and B::Dup — an ambiguous
# short name with no exact full-name match, so the edge must be dropped.
class Caller
  def call
    Dup.call
  end
end
