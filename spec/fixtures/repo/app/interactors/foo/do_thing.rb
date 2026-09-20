# frozen_string_literal: true

# Makes the short name "DoThing" ambiguous. Things#create calls the bare
# `DoThing`, which still resolves to the top-level DoThing by exact full name.
module Foo
  class DoThing
    include Interactor
  end
end
