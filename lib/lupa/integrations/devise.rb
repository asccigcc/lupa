# frozen_string_literal: true

module Lupa
  module Integrations
    # Devise generates its surface from the app, so nothing here is a fixed
    # list of names. Which models call `devise` decides the scopes, and the
    # scopes decide the helper names and the default routes. Guessing instead
    # would invent classes: an app can have hundreds of `current_user` calls
    # and no User model (Avo passes its own `current_user`), and a scope can be
    # mounted onto another model entirely (`devise_for :otc, class_name:
    # "Patient"` -> `current_otc` returns a Patient).
    module Devise
      module_function

      def recognizers = [Scopes]

      def route_recognizers = [Mount]
    end
  end
end
