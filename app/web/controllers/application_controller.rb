module Web
  module Controllers
    class ApplicationController < ActionController::Base
      include Concerns::Authentication
      include Pundit::Authorization

      # Override controller_path to remove Web::Controllers namespace from view lookup
      # This allows controllers in Web::Controllers namespace to use standard view paths
      # Example: Web::Controllers::SessionsController -> views/sessions/
      def self.controller_path
        @controller_path ||= name.sub(/^Web::Controllers::/, '').sub(/Controller$/, '').underscore
      end

      # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
      allow_browser versions: :modern

      # Changes to the importmap will invalidate the etag for HTML responses
      stale_when_importmap_changes

      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

      private

      def user_not_authorized
        flash[:alert] = "You are not authorized to perform this action."
        redirect_back(fallback_location: root_path)
      end
    end
  end
end