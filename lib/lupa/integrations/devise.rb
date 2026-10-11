# frozen_string_literal: true

module Lupa
  module Integrations
    # Devise generates its surface from the app, so nothing here is a fixed
    # list of names. The `devise_for` mounts decide the scopes, and the scopes
    # decide the helper names and the default routes. Guessing instead would
    # invent classes: an app can have hundreds of `current_user` calls and no
    # User model (Avo passes its own `current_user`), it can authenticate a
    # scope onto another model entirely (`devise_for :otc, class_name:
    # "Patient"` -> `current_otc` returns a Patient), and `authenticate_csv!`
    # can be a hand-written filter with no Devise in sight.
    module Devise
      module_function

      def recognizers = [Authenticate]

      def route_recognizers = [Mount]
    end
  end
end
