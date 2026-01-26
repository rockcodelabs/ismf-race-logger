# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      @total_users = User.count
      @admin_users = User.admins.count
      @recent_users = User.order(created_at: :desc).limit(5)
    end
  end
end