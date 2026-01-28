# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module Operations
  module Users
    # Authenticate a user with email and password
    #
    # This operation validates credentials and returns a user struct on success.
    # Uses dependency injection for the user repository (testable).
    #
    # Example:
    #   operation = Operations::Users::Authenticate.new
    #   result = operation.call(email: "user@example.com", password: "password123")
    #
    #   case result
    #   in Success(user)
    #     # user is a Structs::User
    #     session = create_session(user)
    #   in Failure[:validation_failed, errors]
    #     # errors is a hash of validation errors
    #   in Failure[:invalid_credentials]
    #     # email or password incorrect
    #   end
    #
    class Authenticate
      include Dry::Monads[:result]
      include Dry::Monads::Do.for(:call)
      include Import["repos.user"]

      def call(email:, password:)
        # Validate input
        validated = yield validate(email, password)

        # Authenticate via repo
        user = user_repo.authenticate(validated[:email], validated[:password])

        if user
          Success(user)
        else
          Failure(:invalid_credentials)
        end
      end

      private

      # Access the injected repo
      # dry-auto_inject uses the last segment of the key as the method name
      # Import["repos.user"] creates a `user` method (not repos_user)
      alias_method :user_repo, :user

      def validate(email, password)
        contract = Operations::Contracts::AuthenticateUser.new
        result = contract.call(email: email, password: password)

        if result.success?
          Success(result.to_h)
        else
          Failure([ :validation_failed, result.errors.to_h ])
        end
      end
    end
  end
end
