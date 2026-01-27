# frozen_string_literal: true

require "dry/validation"
require_relative "../types"

module Domain
  module Contracts
    class RaceContract < Dry::Validation::Contract
      params do
        required(:name).filled(:string)
        required(:race_date).filled(:date)
        required(:location).filled(:string)
        required(:status).filled(Types::RaceStatus)
      end

      rule(:name) do
        if value.to_s.strip.empty?
          key.failure("cannot be blank")
        elsif value.to_s.length > 255
          key.failure("is too long (maximum 255 characters)")
        end
      end

      rule(:location) do
        if value.to_s.strip.empty?
          key.failure("cannot be blank")
        elsif value.to_s.length > 255
          key.failure("is too long (maximum 255 characters)")
        end
      end

      rule(:status) do
        unless [ "upcoming", "active", "completed" ].include?(value)
          key.failure("must be one of: upcoming, active, completed")
        end
      end

      rule(:race_date) do
        if value && value < Date.today - 365
          key.failure("cannot be more than a year in the past")
        end
      end
    end
  end
end
