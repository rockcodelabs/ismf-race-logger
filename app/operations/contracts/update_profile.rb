# frozen_string_literal: true

require "dry/validation"

module Operations
  module Contracts
    # Validation contract for updating user profile
    #
    # Validates email, password, and PIN updates.
    # All fields are optional - users can update any combination.
    #
    # Rules:
    # - email: valid format if provided
    # - password: minimum 8 characters if provided
    # - password_confirmation: must match password if password is provided
    # - pin: exactly 4 digits if provided
    # - pin_confirmation: must match pin if pin is provided
    #
    class UpdateProfile < Dry::Validation::Contract
      params do
        optional(:email).filled(:string)
        optional(:password).filled(:string)
        optional(:password_confirmation).maybe(:string)
        optional(:pin).filled(:string)
        optional(:pin_confirmation).maybe(:string)
      end

      rule(:email) do
        if key? && value
          key.failure("must be a valid email address") unless value.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
        end
      end

      rule(:password) do
        if key? && value
          key.failure("must be at least 8 characters") if value.length < 8
        end
      end

      rule(:password, :password_confirmation) do
        if key?(:password) && values[:password].present?
          if values[:password_confirmation].blank?
            key(:password_confirmation).failure("must be provided when changing password")
          elsif values[:password] != values[:password_confirmation]
            key(:password_confirmation).failure("must match password")
          end
        end
      end

      rule(:pin) do
        if key? && value
          key.failure("must be exactly 4 digits") unless value.match?(/\A\d{4}\z/)
        end
      end

      rule(:pin, :pin_confirmation) do
        if key?(:pin) && values[:pin].present?
          if values[:pin_confirmation].blank?
            key(:pin_confirmation).failure("must be provided when changing PIN")
          elsif values[:pin] != values[:pin_confirmation]
            key(:pin_confirmation).failure("must match PIN")
          end
        end
      end
    end
  end
end