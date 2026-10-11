# frozen_string_literal: true

module Lupa
  # One declared route: its verb, its path relative to the enclosing scope, and
  # the "controller#action" it points at. Everything a routes file can declare —
  # a verb call, a resource's REST expansion, a Devise mount — is read into
  # these, so RouteRecorder records them all the same way.
  Route = Data.define(:verb, :path, :target) do
    # @return [String, nil] the action, when the target names one (a Devise
    #   route names only a controller)
    def action = target.to_s.split("#", 2)[1]
  end
end
