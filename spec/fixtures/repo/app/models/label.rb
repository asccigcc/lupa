# frozen_string_literal: true

class Label < ApplicationRecord
  belongs_to :thing   # singular accessor: `thing` returns one Thing
  has_many :things    # collection accessor: `things` returns a relation

  def stamp
    thing.track!          # sends Thing #track!, defined in the Trackable concern Thing includes
    things.track!         # a relation is not a record -> dropped
    thing.extended_helper # only in a module Thing *extends* -> dropped
    label = thing
    label.track!          # a bare local is never typed -> dropped
  end
end
