# frozen_string_literal: true

require "dry/monads"

module Application
  module Queries
    module Users
      class Find
        include Dry::Monads[:result]

        def initialize(user_repository: Infrastructure::Persistence::Repositories::UserRepository.new)
          @user_repository = user_repository
        end

        def call(id)
          @user_repository.find(id)
        end

        def by_email(email_address)
          @user_repository.find_by_email(email_address)
        end
      end
    end
  end
end