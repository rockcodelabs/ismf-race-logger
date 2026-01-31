# frozen_string_literal: true

module Operations
  module Contracts
    # UpdateReport Contract
    #
    # Validates input parameters for updating a report.
    # Used for confirming, rejecting, reopening, or adding description.
    #
    # Required fields:
    # - id: integer (report ID)
    #
    # Optional fields:
    # - status: string (pending_review, confirmed, rejected)
    # - description: string
    # - athlete_position: integer (1 or 2 for team races)
    #
    class UpdateReport < Dry::Validation::Contract
      params do
        required(:id).filled(:integer)
        optional(:status).maybe(:string)
        optional(:description).maybe(:string)
        optional(:athlete_position).maybe(:integer)
      end

      rule(:id) do
        key.failure("report not found") unless Report.exists?(value)
      end

      rule(:status) do
        next if value.nil?

        valid_statuses = %w[pending_review confirmed rejected]
        key.failure("must be one of: #{valid_statuses.join(', ')}") unless valid_statuses.include?(value)
      end

      rule(:athlete_position) do
        next if value.nil?

        key.failure("must be 1 or 2") unless [ 1, 2 ].include?(value)
      end
    end
  end
end
