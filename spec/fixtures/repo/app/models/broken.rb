# frozen_string_literal: true

# Deliberately invalid Ruby: the extractor must skip it, not crash.
class Broken < ApplicationRecord
  def oops(
end
