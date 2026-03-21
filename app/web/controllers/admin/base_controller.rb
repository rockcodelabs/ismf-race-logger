# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # BaseController for admin namespace
      #
      # Authorization is handled by Pundit policies in each controller.
      # Each action should call `authorize` with the appropriate resource.
      #
      class BaseController < Web::Controllers::ApplicationController
        before_action :require_authentication

        private

        # Override parent's select_layout to use admin layout in desktop mode
        # while preserving touch (Raspberry Pi kiosk) and phone variants
        def select_layout
          ua = request.user_agent.to_s.downcase
          is_physical_touch = ua.include?("raspberry") || ua.include?("rpi")
          
          if is_physical_touch
            "touch"
          elsif is_mobile_device?(ua)
            "phone"
          else
            "admin"
          end
        end

        # Access to parts factory for wrapping structs with presentation logic
        def parts_factory
          @parts_factory ||= AppContainer["parts.factory"]
        end
        helper_method :parts_factory
      end
    end
  end
end
