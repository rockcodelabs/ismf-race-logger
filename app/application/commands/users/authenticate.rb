# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module Application
  module Commands
    module Users
      class Authenticate
        include Dry::Monads[:result]
        include Dry::Monads::Do.for(:call)

        def initialize(user_repository: Infrastructure::Persistence::Repositories::UserRepository.new)
          @user_repository = user_repository
        end

        def call(email_address:, password:)
          # Validate input
          validated = yield validate(email_address, password)

          # Authenticate user
          user = yield @user_repository.authenticate(
            validated[:email_address],
            validated[:password]
          )

          Success(user)
        end

        private

        def validate(email_address, password)
          contract = Domain::Contracts::AuthenticateUserContract.new
          result = contract.call(email_address: email_address, password: password)

          if result.success?
            Success(result.to_h)
          else
            Failure([:validation_failed, result.errors.to_h])
          end
        end
      end
    end
  end
end