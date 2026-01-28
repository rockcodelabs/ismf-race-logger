# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # DashboardController - Admin dashboard overview
      #
      # Uses repos for data access following Hanami-hybrid architecture.
      # Returns summary structs for collections (performance-optimized).
      #
      # Note: We use explicit container access instead of Import[] because
      # Rails controllers have their own initialization requirements.
      #
      class DashboardController < BaseController
        def index
          @total_users = user_repo.count
          @admin_users = user_repo.where(admin: true).count
          @recent_users = user_repo.all.first(5)
        end

        private

        def user_repo
          @user_repo ||= AppContainer["repos.user"]
        end
      end
    end
  end
end
