# frozen_string_literal: true

Rails.application.routes.draw do
  # Authentication routes - using web layer controllers
  resource :session, controller: "web/controllers/sessions" do
    get :select_user, on: :member
    post :authenticate_pin, on: :member
  end
  resources :passwords, param: :token, controller: "web/controllers/passwords"

  # Profile routes - using web layer controllers
  resource :profile, controller: "web/controllers/profile", only: [:edit, :update]

  # Admin namespace - using web layer controllers
  namespace :admin, module: "web/controllers/admin" do
    root to: "dashboard#index"
    resources :users
    resources :penalties, only: [:index]
    
    # Unified location templates overview
    resources :location_templates, only: [:index]
    
    # Video markers (for ActiveStorage blobs)
    post "videos/markers", to: "videos#create_markers"
    get "videos/markers/:id", to: "videos#show_markers"
    
    # Chunked video uploads
    post "chunked_uploads/initiate", to: "chunked_uploads#initiate"
    post "chunked_uploads/chunk", to: "chunked_uploads#chunk"
    post "chunked_uploads/finalize", to: "chunked_uploads#finalize"
    delete "chunked_uploads/:id", to: "chunked_uploads#destroy"
    
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
        member do
          post :cancel
          post :complete
        end
        
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

    # Reports and Incidents (nested under races)
    resources :races, only: [] do
      resources :reports, controller: "races/reports", only: [:index, :show, :new, :create] do
        collection do
          delete :delete_multiple
          get :videos_index
        end
        member do
          post :confirm
          post :reject
          post :reject_with_incident
          post :reopen
          patch :update_bib
          get :video_thumbnails
        end
        
        # Video attachments for reports
        resources :videos, only: [:create, :destroy], controller: "reports/videos"
      end

      resources :incidents, controller: "races/incidents", only: [:index, :show, :new, :create, :edit, :update, :destroy] do
        collection do
          delete :delete_multiple
          post :merge
        end
        member do
          post :decide
          post :attach_penalties
          post :reopen
          post :add_reports
          post :remove_reports
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
