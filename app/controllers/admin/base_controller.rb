# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :require_authentication
    before_action :require_admin

    layout "admin"

    private

    def require_admin
      unless Current.user&.admin?
        flash[:alert] = "You must be an administrator to access this area."
        redirect_to root_path
      end
    end
  end
end