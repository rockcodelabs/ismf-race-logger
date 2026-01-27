# frozen_string_literal: true

require "dry/validation"
require_relative "../types"

module Domain
  module Contracts
    class ReportContract < Dry::Validation::Contract
      params do
        required(:client_uuid).filled(Types::UUID)
        required(:race_id).filled(:integer)
        required(:user_id).filled(:integer)
        required(:bib_number).filled(:integer)
        required(:description).filled(:string)
        optional(:race_location_id).maybe(:integer)
        optional(:athlete_name).maybe(:string)
        optional(:incident_id).maybe(:integer)
        optional(:video_url).maybe(:string)
      end

      rule(:bib_number) do
        key.failure("must be between 1 and 9999") unless value.between?(1, 9999)
      end

      rule(:client_uuid) do
        unless value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          key.failure("must be a valid UUID")
        end
      end

      rule(:description) do
        if value.to_s.strip.empty?
          key.failure("cannot be blank")
        elsif value.to_s.length > 10_000
          key.failure("is too long (maximum 10,000 characters)")
        end
      end

      rule(:athlete_name) do
        if key? && value && value.to_s.length > 255
          key.failure("is too long (maximum 255 characters)")
        end
      end

      rule(:video_url) do
        if key? && value && !value.to_s.match?(/\Ahttps?:\/\/.+/i)
          key.failure("must be a valid HTTP/HTTPS URL")
        end
      end
    end
  end
end