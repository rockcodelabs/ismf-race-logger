# frozen_string_literal: true

require "dry/validation"

module Operations
  module Contracts
    # Contract for authenticating a user
    #
    # Validates email and password input before authentication attempt.
    #
    # Example:
    #   contract = Operations::Contracts::AuthenticateUser.new
    #   result = contract.call(email: "user@example.com", password: "password123")
    #
    #   if result.success?
    #     # proceed with authentication
    #   else
    #     result.errors.to_h # => { email: ["must be a valid email"] }
    #   end
    #
    class AuthenticateUser < Dry::Validation::Contract
      params do
        required(:email).filled(:string)
        required(:password).filled(:string)
      end

      rule(:email) do
        unless value.match?(URI::MailTo::EMAIL_REGEXP)
          key.failure("must be a valid email address")
        end
      end

      rule(:password) do
        key.failure("must be at least 8 characters") if value.length < 8
      end
    end
  end
end
