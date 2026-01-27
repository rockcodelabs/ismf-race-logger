Rails.application.routes.draw do
  # Authentication routes - using web layer controllers
  resource :session, controller: "web/controllers/sessions"
  resources :passwords, param: :token

  # Admin namespace
  namespace :admin do
    root to: "dashboard#index"
    resources :users
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path - redirect to admin for now
  root "home#index"
end