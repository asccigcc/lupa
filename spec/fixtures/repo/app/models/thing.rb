# frozen_string_literal: true

class Thing < ApplicationRecord
  include Trackable

  has_many :widgets
  belongs_to :owner
end
