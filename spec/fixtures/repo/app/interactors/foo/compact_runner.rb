# frozen_string_literal: true

# Compact style: only Foo::CompactRunner is in lexical scope, not Foo.
class Foo::CompactRunner
  def run = DoThing.call
end
