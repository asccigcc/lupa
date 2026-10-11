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
        # are not names anything resolves through.
        # @return [Array<Array(String, String, String)>] [name, model, owner]
        def accessors
          ["current_#{name}", "authenticate_#{name}!"].map { |helper| [helper, model, model] }
        end
      end
    end
  end
end
