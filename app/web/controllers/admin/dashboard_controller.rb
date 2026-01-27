# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      class DashboardController < BaseController
        def index
          @total_users = Infrastructure::Persistence::Records::UserRecord.count
          @admin_users = Infrastructure::Persistence::Records::UserRecord.admins.count
          @recent_users = Infrastructure::Persistence::Records::UserRecord.order(created_at: :desc).limit(5)
        end
      end
    end
  end
end
