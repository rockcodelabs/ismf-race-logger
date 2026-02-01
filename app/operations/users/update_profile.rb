# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module Operations
  module Users
    # Update user profile (email, password, PIN)
    #
    # This operation allows users to update their own profile information
    # without requiring email confirmation. All fields are optional.
    #
    # Example:
    #   operation = Operations::Users::UpdateProfile.new
    #   result = operation.call(
    #     user_id: 123,
    #     email: "new@example.com",
    #     password: "newpassword123",
    #     password_confirmation: "newpassword123",
    #     pin: "1234",
    #     pin_confirmation: "1234"
    #   )
    #
    #   case result
    #   in Success(user)
    #     # user is a Structs::User
    #   in Failure[:validation_failed, errors]
    #     # errors is a hash of validation errors
    #   in Failure[:user_not_found]
    #     # user doesn't exist
    #   in Failure[:email_taken]
    #     # email already in use by another user
    #   end
    #
    class UpdateProfile
      include Dry::Monads[:result]
      include Dry::Monads::Do.for(:call)
      include Import["repos.user"]

      def call(user_id:, **attrs)
        # Validate input
        validated = yield validate(attrs)

        # Check if user exists
        user_record = User.find_by(id: user_id)
        return Failure(:user_not_found) unless user_record

        # Check email uniqueness if email is being changed
        if validated[:email] && validated[:email] != user_record.email_address
          existing = User.where(email_address: validated[:email]).where.not(id: user_id).exists?
          return Failure(:email_taken) if existing
        end

        # Build update attributes
        update_attrs = {}
        update_attrs[:email_address] = validated[:email] if validated[:email]
        update_attrs[:password] = validated[:password] if validated[:password]
        update_attrs[:pin] = validated[:pin] if validated[:pin]

        # Update user if there are attributes to update
        if update_attrs.any?
          if user_record.update(update_attrs)
            # Return updated struct from repo
            updated_user = user_repo.find(user_id)
            Success(updated_user)
          else
            Failure([:update_failed, user_record.errors.messages])
          end
        else
          # No attributes to update, return current user
          current_user = user_repo.find(user_id)
          Success(current_user)
        end
      end

      private

      # Access the injected repo
      alias_method :user_repo, :user

      def validate(attrs)
        contract = Operations::Contracts::UpdateProfile.new
        result = contract.call(attrs)

        if result.success?
          Success(result.to_h)
        else
          Failure([:validation_failed, result.errors.to_h])
        end
      end
    end
  end
end