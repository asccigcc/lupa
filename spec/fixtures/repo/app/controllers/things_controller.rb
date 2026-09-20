# frozen_string_literal: true

class ThingsController < ApplicationController
  def create
    DoThing.call(value: 1)
    NotifyJob.perform_later(1)
    External::Api.call # undefined in repo -> must be dropped
  end
end
