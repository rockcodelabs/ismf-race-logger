# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      class DashboardController < BaseController
        def index
          @total_users = User.count
          @admin_users = User.where(admin: true).count
          @recent_users = User.order(created_at: :desc).limit(5)
        end
      end
    end
  end
end
