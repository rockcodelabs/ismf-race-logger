# frozen_string_literal: true

module Operations
  module Contracts
    # Validates input for creating a race
    #
    # Required fields:
    # - competition_id: ID of parent competition
    # - race_type_id: ID of race type (Individual, Sprint, etc.)
    # - name: Display name of the race
    # - stage_type: Stage type (Qualification, Heat, Quarterfinal, Semifinal, Final)
    #
    # Optional fields:
    # - heat_number: Heat number (1-10) for multi-heat stages
    # - scheduled_at: When the race is scheduled to start
    #
    # Auto-generated fields (not in params):
    # - stage_name: Computed from stage_type and heat_number
    # - position: Auto-assigned based on race_type
    # - status: Defaults to "scheduled"
    #
    # @example
    #   contract = Operations::Contracts::CreateRace.new
    #   result = contract.call(
    #     competition_id: 1,
    #     race_type_id: 3,
    #     name: "Women's Sprint - Qualification",
    #     stage_type: "Qualification",
    #     heat_number: nil,
    #     scheduled_at: Time.current + 2.hours
    #   )
    #   result.success? # => true/false
    #   result.errors.to_h # => { name: ["must be filled"] }
    #
    class CreateRace < Dry::Validation::Contract
      params do
        # Required fields
        required(:competition_id).filled(:integer)
        required(:race_type_id).filled(:integer)
        required(:name).filled(:string)
        required(:stage_type).filled(:string)
        required(:gender_category).filled(:string)

        # Optional fields
        optional(:heat_number).maybe(:integer)
        optional(:scheduled_at).maybe(:time)
      end

      # Validate name length
      rule(:name) do
        key.failure("must be at least 3 characters") if value && value.length < 3
        key.failure("must be at most 255 characters") if value && value.length > 255
      end

      # Validate stage_type is one of the allowed values
      rule(:stage_type) do
        valid_stages = %w[Qualification Heat Quarterfinal Semifinal Final]
        unless valid_stages.include?(value)
          key.failure("must be one of: #{valid_stages.join(', ')}")
        end
      end

      # Validate gender_category is one of the allowed values
      rule(:gender_category) do
        valid_categories = %w[M W MM WW MW]
        unless valid_categories.include?(value)
          key.failure("must be one of: M (Men), W (Women), MM (Men's Team), WW (Women's Team), MW (Mixed Team)")
        end
      end

      # Validate heat_number range
      rule(:heat_number) do
        if value.present?
          key.failure("must be between 1 and 10") unless value.between?(1, 10)
        end
      end

      # Validate competition_id exists
      rule(:competition_id) do
        unless Competition.exists?(value)
          key.failure("competition not found")
        end
      end

      # Validate race_type_id exists
      rule(:race_type_id) do
        unless RaceType.exists?(value)
          key.failure("race type not found")
        end
      end

      # Note: scheduled_at can be in the past (for historical data entry)
      # or in the future (for upcoming races). No validation needed.
    end
  end
end