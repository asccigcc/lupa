# frozen_string_literal: true

# An app with no Devise that happens to use the names Devise would generate.
# They are ordinary methods here, so nothing may be attributed to the gem.
class ApplicationController
  before_action :authenticate_patient!

  def create
    current_patient.update(seen_at: Time.now)
  end

  private

  def authenticate_patient!
    redirect_to "/login" unless session[:patient_id]
  end

  def current_patient
    @current_patient ||= Patient.find_by(id: session[:patient_id])
  end
end
