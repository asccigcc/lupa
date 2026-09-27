# frozen_string_literal: true

# Reopens Assemble from a nested file; the node must still point at assemble.rb,
# but edges recorded here must point at this file.
class Assemble
  def self.rerun = DoOther.call

  class Step
  end
end
