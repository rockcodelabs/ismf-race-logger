# frozen_string_literal: true

module Operations
  module Contracts
    # AttachPenalties Contract
    #
    # Validates input parameters for attaching penalties to an incident.
    # Penalties are reference data selected by penalty_id.
    #
    # Required fields:
    # - incident_id: integer (must be a valid incident)
    # - penalty_ids: array of integers (penalty IDs to attach)
    #
    # Business rules:
    # - Incident must exist
    # - All penalty_ids must reference valid penalties
    # - Duplicate penalty_ids are allowed (will be deduplicated)
    #
    class AttachPenalties < Dry::Validation::Contract
      params do
        required(:incident_id).filled(:integer)
        required(:penalty_ids).array(:integer)
      end

      # Validate incident exists
      rule(:incident_id) do
        key.failure("incident not found") unless Incident.exists?(value)
      end

      # Validate all penalty_ids reference valid penalties
      rule(:penalty_ids) do
        next if value.empty?

        unique_ids = value.uniq
        existing_count = Penalty.where(id: unique_ids).count

        if existing_count != unique_ids.size
          key.failure("one or more penalties not found")
        end
      end
    end
  end
end
