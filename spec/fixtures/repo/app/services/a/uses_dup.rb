# frozen_string_literal: true

module A
  class UsesDup
    def run = Dup.call
  end
end
