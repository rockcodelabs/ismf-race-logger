# frozen_string_literal: true

module Operations
  module Contracts
    # DecideIncident Contract
    #
    # Validates input parameters for deciding (approving/rejecting) an incident.
    # Used when making a final decision on an incident.
    #
    # Required fields:
    # - id: integer (incident ID)
    # - status: string (approved or rejected)
    # - user_id: integer (who is making the decision)
    #
    # Optional fields:
    # - description: string (notes about the decision)
    # - penalty_ids: array of integers (penalties to attach)
    #
    class DecideIncident < Dry::Validation::Contract
      params do
        required(:id).filled(:integer)
        required(:status).filled(:string)
        required(:user_id).filled(:integer)
        optional(:description).maybe(:string)
        optional(:penalty_ids).maybe(:array)
      end

      # Validate incident exists and is pending
      rule(:id) do
        incident = Incident.find_by(id: value)
        if incident.nil?
          key.failure("incident not found")
        elsif incident.status != "pending"
          key.failure("incident must be pending to decide (current status: #{incident.status})")
        end
      end

      # Validate status is a valid decision
      rule(:status) do
        valid_statuses = %w[approved rejected]
        key.failure("must be one of: #{valid_statuses.join(', ')}") unless valid_statuses.include?(value)
      end

      # Validate user exists
      rule(:user_id) do
        key.failure("must be a valid user") unless User.exists?(value)
      end

      # Validate penalty_ids if provided
      rule(:penalty_ids) do
        next if value.nil? || value.empty?

        # Ensure all values are integers
        unless value.all? { |id| id.is_a?(Integer) }
          key.failure("must be an array of integers")
          next
        end

        # Validate all penalty IDs exist
        existing_count = Penalty.where(id: value).count
        if existing_count != value.size
          key.failure("contains invalid penalty IDs")
        end
      end

      # When approving, at least one penalty OR description must be provided
      rule(:penalty_ids, :description, :status) do
        if values[:status] == "approved"
          has_penalty = values[:penalty_ids].present? && !values[:penalty_ids].empty?
          has_description = values[:description].present? && !values[:description].strip.empty?
          
          unless has_penalty || has_description
            key.failure("at least one penalty or a description must be provided when approving an incident")
          end
        end
      end
    end
  end
end
