# frozen_string_literal: true

Rails.application.routes.draw do
  # Authentication routes - using web layer controllers
  resource :session, controller: "web/controllers/sessions"
  resources :passwords, param: :token, controller: "web/controllers/passwords"

  # Admin namespace - using web layer controllers
  namespace :admin, module: "web/controllers/admin" do
    root to: "dashboard#index"
    resources :users
    resources :penalties, only: [:index]
    
    # Race type location templates
    resources :race_types, only: [] do
      resources :location_templates, controller: "race_types/location_templates" do
        collection do
          post :reorder
        end
      end
    end
    
    resources :competitions do
      resources :races do
        resources :participations, only: [:destroy], controller: "races/participations" do
          collection do
            post :copy
          end
        end
      end
    end
    
    # Race locations (nested under races)
    resources :races, only: [] do
      resources :race_locations, controller: "races/race_locations" do
        collection do
          post :reorder
        end
      end
    end
    
    # Athlete import routes (nested under races)
    resources :races, only: [] do
      resource :imports, only: [:new, :create], controller: "races/imports", as: :import
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path - using web layer controllers
  root "web/controllers/home#index"

  # Make controllers from app/web findable
  # Rails expects controllers in app/controllers, but ours are in app/web/controllers
  # This is handled by Zeitwerk configuration in config/application.rb
end
