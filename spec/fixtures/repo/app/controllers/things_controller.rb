# frozen_string_literal: true

class ThingsController < ApplicationController
  before_action :authenticate_owner!     # devise scope -> authenticates Owner
  before_action :authenticate_ghost!     # no such scope -> dropped, not guessed
  before_action :set_thing               # not a devise helper -> no edge

  def create
    DoThing.call(value: 1)
    NotifyJob.perform_later(1)
    External::Api.call # undefined in repo -> must be dropped
  end

  def update
    current_owner.update(name: "x")  # devise accessor -> persists Owner
    current_ghost.update(name: "x")  # no such devise scope -> dropped, not guessed
  end
end
