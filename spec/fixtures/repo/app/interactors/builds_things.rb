# frozen_string_literal: true

# A fresh instance is its class's code: `.new(...).call` is a handoff, any other
# method an invoke, and a write on a built record a write to that model.
class BuildsThings
  def call
    ShipIt.new.call            # calls -> ShipIt
    ShipIt.new.summary         # invokes -> ShipIt
    Thing.new(name: "x").save! # persists -> Thing
    External::Api.new.call     # undefined in repo -> dropped
    ShipIt.build.call          # a class method named build may return anything -> dropped
  end
end
