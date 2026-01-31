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
        # Touch mode still uses touch layout (inherited from parent)
        def select_layout
          touch_display? ? "touch" : "admin"
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
