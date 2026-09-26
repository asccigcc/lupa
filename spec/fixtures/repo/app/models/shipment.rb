# frozen_string_literal: true

# Irregular plurals and singular names ending in "s" — naming-convention traps.
class Shipment < ApplicationRecord
  has_many :deliveries   # -> Delivery (ies -> y)
  has_many :addresses    # -> Address (sses -> ss)
  belongs_to :status     # -> Status (singular already; never "Statu")
  has_one :address       # -> Address (singular already; never "Addres")
end
