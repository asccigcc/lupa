# frozen_string_literal: true

# Thing *extends* this, so `extended_helper` is a method on the class object,
# never on a Thing record: a `thing.extended_helper` send must be dropped.
module Countable
  def extended_helper; end
end
