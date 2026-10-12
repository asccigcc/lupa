# frozen_string_literal: true

# Opens Thing only to nest something under it, from a directory that sorts
# before app/models. The Thing node must still be the model.
class Thing
  class Configurator
    include Interactor

    def call
      Thing.update_all(stamped: true) # persists -> Thing, the model this reopens
    end
  end
end
