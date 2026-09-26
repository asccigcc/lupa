# frozen_string_literal: true

class ShipIt
  def call
    shipment.deliveries.create! # persists -> Delivery (irregular plural accessor)
  end
end
