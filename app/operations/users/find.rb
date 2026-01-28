# frozen_string_literal: true

require "dry/monads"

module Operations
  module Users
    # Find a user by ID or email
    #
    # This operation returns a user struct or a failure result.
    # Uses dependency injection for the user repository (testable).
    #
    # Example:
    #   operation = Operations::Users::Find.new
    #
    #   # Find by ID
    #   result = operation.call(id: 1)
    #
    #   # Find by email
    #   result = operation.by_email("user@example.com")
    #
    #   case result
    #   in Success(user)
    #     # user is a Structs::User
    #   in Failure[:not_found]
    #     # user not found
    #   end
    #
    class Find
      include Dry::Monads[:result]
      include Import["repos.user"]

      def call(id:)
        user = user_repo.find(id)

        if user
          Success(user)
        else
          Failure(:not_found)
        end
      end

      def by_email(email)
        user = user_repo.find_by_email(email)

        if user
          Success(user)
        else
          Failure(:not_found)
        end
      end

      private

      # Access the injected repo
      # dry-auto_inject uses the last segment of the key as the method name
      # Import["repos.user"] creates a `user` method (not repos_user)
      alias_method :user_repo, :user
    end
  end
end