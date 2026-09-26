# frozen_string_literal: true

module Foo
  class Runner
    def nested = DoThing.call
    def anchored = ::DoThing.call!
  end
end
