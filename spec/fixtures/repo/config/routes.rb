# frozen_string_literal: true

Rails.application.routes.draw do
  get "things", to: "things#index"
  post "/things/bulk", to: "things#bulk"

  # hash-rocket form
  get "up" => "things#health"

  devise_for :patients, controllers: {
    registrations: "patients/registrations"
  }

  # no controllers: override — still declares the scope that makes
  # `current_owner` and `authenticate_owner!` resolve to Owner
  devise_for :owners

  namespace :admin do
    resources :widgets
  end

  scope module: "admin" do
    patch "widgets/sync", to: "widgets#sync" # module prefix, no path prefix
    get "abs", to: "/things#abs"             # leading slash ignores the module prefix
  end

  resource :thing              # singular -> pluralized ThingsController
  resources :gadgets, controller: "things" # explicit controller: override

  # points at a controller not defined in the repo -> dropped, not guessed
  get "external", to: "external/api#show"
end
