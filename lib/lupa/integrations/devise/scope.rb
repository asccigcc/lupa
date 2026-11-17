# frozen_string_literal: true

module Lupa
  module Integrations
    module Devise
      # One Devise scope: the name Devise knows it by and the model it
      # authenticates.
      Scope = Data.define(:name, :model) do
        # Devise generates four helpers per scope, of which two *denote* the
        # model plainly enough to resolve an edge through: the record accessor a
        # write goes through (`current_patient.update`) and the filter that
        # demands the scope (`authenticate_patient!`). `patient_signed_in?` and
        # `patient_session` answer something *about* the scope instead, so they
        # are not names anything resolves through. Only `current_patient` is
        # the signed-in record itself, so only it can type a `sends`.
        # @return [Array<Array(String, String, String, Boolean)>] [name, model, owner, singular]
        def accessors
          [["current_#{name}", model, model, true], ["authenticate_#{name}!", model, model, false]]
        end
      end
    end
  end
end
