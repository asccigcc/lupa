# frozen_string_literal: true

Rails.application.routes.draw do
  resources :patients, only: %i[index]
end
