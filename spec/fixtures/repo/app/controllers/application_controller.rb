# frozen_string_literal: true

class ApplicationController
  # exempts actions from the filter rather than requiring it -> no edge
  skip_before_action :authenticate_owner!, only: %i[health]
end
