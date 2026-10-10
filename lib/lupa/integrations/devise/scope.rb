# frozen_string_literal: true

module Lupa
  module Integrations
    module Devise
      # One Devise scope: the name Devise knows it by, the model it
      # authenticates, and the modules enabled on it (which decide the default
      # routes `devise_for` mounts).
      Scope = Data.define(:name, :model, :modules) do
        # Devise names the record accessor off the scope. The other generated
        # helpers either answer a question (`patient_signed_in?`) or perform
        # auth (`authenticate_patient!`) rather than return the record, so they
        # are not receivers a write can resolve through.
        # @return [Array<Array(String, String, String)>] [accessor, model, owner]
        def accessors = [["current_#{name}", model, model]]
      end
    end
  end
end
