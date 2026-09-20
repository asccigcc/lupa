# frozen_string_literal: true

class Thing < ApplicationRecord
  include Trackable

  has_many :widgets
  belongs_to :owner

  after_create_commit :notify_owner       # triggers -> notify_owner (marker, not a node)
  before_save :normalize, :stamp          # two symbols -> two triggers edges
  after_update :recount, if: :changed?    # if: option ignored; changed? not recorded
  after_destroy { cleanup }               # block form, no symbol -> dropped
end
