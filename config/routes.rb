# frozen_string_literal: true

Rails.application.routes.draw do
  root to: redirect('/control')

  resources :control, only: :index
end
