# frozen_string_literal: true

class Widget < ApplicationRecord
  # Shares the association name `gizmos` with Owner but points elsewhere, making
  # `gizmos` ambiguous across the app (Widget here, Owner there) -> unresolvable.
  has_many :gizmos, class_name: "Widget"
end
