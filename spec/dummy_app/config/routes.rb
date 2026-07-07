# frozen_string_literal: true

DummyApp::Application.routes.draw do
  # Needed for :show_in_app tests
  resources :players, only: [:show]

  delete "/logout", to: ->(_env) { [204, {}, []] }, as: :logout

  mount RailsAdminNext::Engine => "/admin", :as => "rails_admin_next"
  root to: "rails_admin_next/main#dashboard"
end
