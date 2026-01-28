# frozen_string_literal: true

require "dry/monads"

module Operations
  module Users
    # List users with various filters
    #
    # This operation returns collections of user summary structs.
    # Uses dependency injection for the user repository (testable).
    #
    # Example:
    #   operation = Operations::Users::List.new
    #
    #   # List all users
    #   result = operation.call
    #
    #   # List admins only
    #   result = operation.admins
    #
    #   # List referees
    #   result = operation.referees
    #
    #   # List by role
    #   result = operation.with_role("jury_president")
    #
    #   # Search users
    #   result = operation.search("john")
    #
    #   case result
    #   in Success(users)
    #     # users is an array of Structs::UserSummary
    #   end
    #
    class List
      include Dry::Monads[:result]
      include Import["repos.user"]

      # List all users
      def call
        users = user_repo.all
        Success(users)
      end

      # List admin users only
      def admins
        users = user_repo.admins
        Success(users)
      end

      # List referee users (national and international)
      def referees
        users = user_repo.referees
        Success(users)
      end

      # List users with a specific role
      def with_role(role_name)
        users = user_repo.with_role(role_name)
        Success(users)
      end

      # Search users by email or name
      def search(query)
        users = user_repo.search(query)
        Success(users)
      end

      private

      # Access the injected repo
      # dry-auto_inject uses the last segment of the key as the method name
      # Import["repos.user"] creates a `user` method (not repos_user)
      alias_method :user_repo, :user
    end
  end
end