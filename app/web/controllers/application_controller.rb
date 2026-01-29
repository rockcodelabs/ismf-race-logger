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

      # Dynamic layout selection based on touch mode
      # This is evaluated per-request, avoiding class-level state contamination
      layout :select_layout

      # Make touch_display? available in views
      helper_method :touch_display?

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

      # Set request variant for Turbo Native apps and touch displays
      # This enables automatic template variant selection:
      # - Web: index.html.erb
      # - Native: index.turbo_native.html.erb (falls back to index.html.erb)
      # - Touch: index.touch.html.erb (falls back to index.html.erb)
      def set_variant
        request.variant = :turbo_native if turbo_native_app?
        
        is_touch = touch_display?
        Rails.logger.info "=== TOUCH DEBUG ==="
        Rails.logger.info "touch_display? result: #{is_touch}"
        Rails.logger.info "params[:touch]: #{params[:touch]}"
        Rails.logger.info "cookies[:touch_display]: #{cookies[:touch_display]}"
        Rails.logger.info "User-Agent: #{request.user_agent}"
        
        if is_touch
          request.variant = :touch
          Rails.logger.info "VARIANT SET TO: #{request.variant.inspect}"
        else
          Rails.logger.info "VARIANT NOT SET (touch=false)"
        end
        
        Rails.logger.info "Final request.variant: #{request.variant.inspect}"
        Rails.logger.info "==================="
      end

      # Detect Turbo Native app requests
      # Turbo Native sends a specific User-Agent header
      def turbo_native_app?
        request.user_agent.to_s.include?("Turbo Native")
      end

      # Detect touch displays
      # Priority order:
      # 1. Explicit query parameter (?touch=1 or ?touch=0)
      # 2. Cookie preference (persisted from previous visit)
      # 3. User-Agent detection (Raspberry Pi, mobile browsers)
      # 4. Small screen dimensions (width < 900px, likely touch device)
      #
      # Note: CSS uses @media (any-pointer: coarse) for automatic touch detection
      # This server-side detection handles initial page load and variant selection
      def touch_display?
        # Detect if this is a physical touch display (Raspberry Pi)
        ua = request.user_agent.to_s.downcase
        is_physical_touch_display = ua.include?("raspberry") || ua.include?("rpi")
        
        # Physical touch displays MUST always stay in touch mode
        if is_physical_touch_display
          Rails.logger.info "TOUCH: Physical touch display detected (Raspberry Pi), forcing touch mode"
          cookies[:touch_display] = { value: "1", expires: 1.year.from_now }
          return true
        end
        
        # For desktop/mobile: Allow explicit override via query parameter
        if params[:touch].present?
          touch_enabled = params[:touch] == "1"
          Rails.logger.info "TOUCH: Setting cookie to #{touch_enabled ? '1' : '0'} from params"
          cookies[:touch_display] = { value: touch_enabled ? "1" : "0", expires: 1.year.from_now }
          return touch_enabled
        end
        
        # Check persisted cookie preference
        if cookies[:touch_display] == "1"
          Rails.logger.info "TOUCH: Cookie is '1', returning true"
          return true
        end
        if cookies[:touch_display] == "0"
          Rails.logger.info "TOUCH: Cookie is '0', returning false"
          return false
        end
        
        # Detect mobile devices from User-Agent
        if ua.include?("mobile") || ua.include?("android") ||
           ua.include?("iphone") || ua.include?("ipad")
          Rails.logger.info "TOUCH: Detected mobile device from User-Agent, setting cookie"
          cookies[:touch_display] = { value: "1", expires: 1.year.from_now }
          return true
        end
        
        Rails.logger.info "TOUCH: No touch detected, returning false"
        false
      end

      # Select layout dynamically per-request based on device type
      # This method is called for each request via `layout :select_layout`
      # and returns the appropriate layout name without modifying class-level state.
      #
      # Logic:
      # - Touch device → "touch" layout
      # - Desktop device → "application" layout (child controllers can override)
      def select_layout
        touch_display? ? "touch" : "application"
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
