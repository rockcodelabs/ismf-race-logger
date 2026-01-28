# frozen_string_literal: true

module Web
  module Controllers
    # ApplicationController - Base controller for web layer
    #
    # Provides:
    # - Authentication (via concern)
    # - Authorization (Pundit)
    # - Turbo Native variant detection
    # - Parts factory access for wrapping structs
    #
    class ApplicationController < ActionController::Base
      include Concerns::Authentication
      include Pundit::Authorization

      # Explicitly set application layout
      layout "application"

      # Set Turbo Native variant for template selection
      before_action :set_variant

      # Override controller_path to remove Web::Controllers namespace from view lookup
      # This allows controllers in Web::Controllers namespace to use standard view paths
      # Example: Web::Controllers::SessionsController -> views/sessions/
      def self.controller_path
        @controller_path ||= name.sub(/^Web::Controllers::/, "").sub(/Controller$/, "").underscore
      end

      # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
      allow_browser versions: :modern

      # Changes to the importmap will invalidate the etag for HTML responses
      stale_when_importmap_changes

      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

      private

      # Set request variant for Turbo Native apps
      # This enables automatic template variant selection:
      # - Web: index.html.erb
      # - Native: index.turbo_native.html.erb (falls back to index.html.erb)
      def set_variant
        request.variant = :turbo_native if turbo_native_app?
      end

      # Detect Turbo Native app requests
      # Turbo Native sends a specific User-Agent header
      def turbo_native_app?
        request.user_agent.to_s.include?("Turbo Native")
      end

      # Access the parts factory for wrapping structs with presentation logic
      # Usage in controllers:
      #   @user = parts_factory.wrap(user_struct)
      #   @users = parts_factory.wrap_many(user_structs)
      def parts_factory
        @parts_factory ||= AppContainer["parts.factory"]
      end

      # Helper to access broadcasters from container
      # Usage:
      #   broadcaster(:incident).created(incident)
      #   broadcaster(:user).updated(user)
      def broadcaster(name)
        AppContainer["broadcasters.#{name}"]
      end

      def user_not_authorized
        flash[:alert] = "You are not authorized to perform this action."
        redirect_back(fallback_location: root_path)
      end
    end
  end
end
