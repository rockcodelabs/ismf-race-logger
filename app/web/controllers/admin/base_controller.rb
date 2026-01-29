# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      class BaseController < Web::Controllers::ApplicationController
        before_action :require_authentication
        before_action :require_admin

        private

        def require_admin
          unless Current.user&.admin?
            flash[:alert] = "You must be an administrator to access this area."
            redirect_to root_path
          end
        end

        # Override parent's select_layout to use admin layout in desktop mode
        # Touch mode still uses touch layout (inherited from parent)
        def select_layout
          touch_display? ? "touch" : "admin"
        end
      end
    end
  end
end
