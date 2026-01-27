# frozen_string_literal: true

require "dry/monads"

module Application
  module Queries
    module Users
      class All
        include Dry::Monads[:result]

        def initialize(user_repository: Infrastructure::Persistence::Repositories::UserRepository.new)
          @user_repository = user_repository
        end

        def call
          @user_repository.all
        end

        def admins
          @user_repository.admins
        end

        def referees
          @user_repository.referees
        end

        def with_role(role_name)
          @user_repository.with_role(role_name)
        end
      end
    end
  end
end
