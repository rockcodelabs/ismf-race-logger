# frozen_string_literal: true

require "dry/validation"
require_relative "../types"

module Domain
  module Contracts
    class IncidentContract < Dry::Validation::Contract
      params do
        required(:race_id).filled(:integer)
        required(:status).filled(Types::IncidentStatus)
        required(:decision).filled(Types::DecisionType)
        optional(:race_location_id).maybe(:integer)
        optional(:officialized_by_user_id).maybe(:integer)
        optional(:decided_by_user_id).maybe(:integer)
        optional(:officialized_at).maybe(:date_time)
        optional(:decided_at).maybe(:date_time)
        optional(:decision_notes).maybe(:string)
      end

      rule(:status) do
        unless [ "unofficial", "official" ].include?(value)
          key.failure("must be either 'unofficial' or 'official'")
        end
      end

      rule(:decision) do
        unless [ "pending", "penalty_applied", "rejected", "no_action" ].include?(value)
          key.failure("must be one of: pending, penalty_applied, rejected, no_action")
        end
      end

      rule(:decision, :decided_by_user_id) do
        if values[:decision] != "pending" && values[:decided_by_user_id].nil?
          key(:decided_by_user_id).failure("must be present when decision is not pending")
        end
      end

      rule(:decision, :decided_at) do
        if values[:decision] != "pending" && values[:decided_at].nil?
          key(:decided_at).failure("must be present when decision is not pending")
        end
      end

      rule(:status, :officialized_by_user_id) do
        if values[:status] == "official" && values[:officialized_by_user_id].nil?
          key(:officialized_by_user_id).failure("must be present when status is official")
        end
      end

      rule(:status, :officialized_at) do
        if values[:status] == "official" && values[:officialized_at].nil?
          key(:officialized_at).failure("must be present when status is official")
        end
      end

      rule(:decision_notes) do
        if key? && value && value.to_s.length > 5_000
          key.failure("is too long (maximum 5,000 characters)")
        end
      end

      rule(:officialized_at, :decided_at) do
        if values[:officialized_at] && values[:decided_at]
          if values[:decided_at] < values[:officialized_at]
            key(:decided_at).failure("cannot be before officialization date")
          end
        end
      end
    end
  end
end
