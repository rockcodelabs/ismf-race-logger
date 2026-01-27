# frozen_string_literal: true

require "dry/validation"
require_relative "../types"

module Domain
  module Contracts
    class AuthenticateUserContract < Dry::Validation::Contract
      params do
        required(:email_address).filled(Types::Email)
        required(:password).filled(:string, min_size?: 8)
      end

      rule(:email_address) do
        key.failure("must be a valid email address") unless value.match?(URI::MailTo::EMAIL_REGEXP)
      end

      rule(:password) do
        key.failure("must be at least 8 characters") if value.length < 8
      end
    end
  end
end