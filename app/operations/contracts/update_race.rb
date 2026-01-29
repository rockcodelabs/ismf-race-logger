# frozen_string_literal: true

module Operations
  module Contracts
    # Validates input for updating a race
    #
    # Optional fields (all can be updated independently):
    # - name: Display name of the race
    # - stage_type: Stage type (Qualification, Heat, Quarterfinal, Semifinal, Final)
    # - heat_number: Heat number (1-10) for multi-heat stages
    # - scheduled_at: When the race is scheduled to start
    # - position: Sort order within competition
    # - status: Race status (scheduled, in_progress, completed, cancelled)
    #
    # Fields that CANNOT be updated:
    # - competition_id: Race is tied to competition
    # - race_type_id: Cannot change if participants exist (enforced in operation)
    #
    # Auto-generated fields:
    # - stage_name: Recomputed from stage_type and heat_number if either changes
    #
    # @example
    #   contract = Operations::Contracts::UpdateRace.new
    #   result = contract.call(
    #     name: "Women's Sprint - Semifinal 1",
    #     stage_type: "Semifinal",
    #     heat_number: 1,
    #     scheduled_at: Time.current + 3.hours
    #   )
    #   result.success? # => true/false
    #   result.errors.to_h # => { name: ["must be filled"] }
    #
    class UpdateRace < Dry::Validation::Contract
      params do
        # All fields are optional for updates
        optional(:name).filled(:string)
        optional(:stage_type).filled(:string)
        optional(:heat_number).maybe(:integer)
        optional(:scheduled_at).maybe(:time)
        optional(:position).filled(:integer)
        optional(:status).filled(:string)
      end

      # Validate name length
      rule(:name) do
        if value.present?
          key.failure("must be at least 3 characters") if value.length < 3
          key.failure("must be at most 255 characters") if value.length > 255
        end
      end

      # Validate stage_type is one of the allowed values
      rule(:stage_type) do
        if value.present?
          valid_stages = %w[Qualification Heat Quarterfinal Semifinal Final]
          unless valid_stages.include?(value)
            key.failure("must be one of: #{valid_stages.join(', ')}")
          end
        end
      end

      # Validate heat_number range
      rule(:heat_number) do
        if value.present?
          key.failure("must be between 1 and 10") unless value.between?(1, 10)
        end
      end

      # Validate status is one of the allowed values
      rule(:status) do
        if value.present?
          valid_statuses = %w[scheduled in_progress completed cancelled]
          unless valid_statuses.include?(value)
            key.failure("must be one of: #{valid_statuses.join(', ')}")
          end
        end
      end

      # Validate position is positive
      rule(:position) do
        if value.present?
          key.failure("must be greater than or equal to 0") if value < 0
        end
      end
    end
  end
end