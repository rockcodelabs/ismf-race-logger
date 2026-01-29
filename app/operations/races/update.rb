# frozen_string_literal: true

module Operations
  module Races
    # Update an existing race
    #
    # This operation:
    # - Validates input parameters
    # - Enforces business rules (can't change race_type if participants exist)
    # - Computes stage_name from stage_type and heat_number
    # - Updates the race record
    #
    # Business Rules:
    # - Can't edit completed races
    # - Can't change race_type if participants exist (future enhancement)
    # - Can always update: name, stage_type, heat_number, scheduled_at, position
    #
    # @example
    #   result = Operations::Races::Update.new.call(
    #     id: 1,
    #     name: "Women's Sprint - Semifinal 1",
    #     stage_type: "Semifinal",
    #     heat_number: 1,
    #     scheduled_at: Time.current + 3.hours
    #   )
    #
    #   case result
    #   in Success(race)
    #     # race is a Structs::Race
    #   in Failure(errors)
    #     # errors is a hash of validation errors or business rule violations
    #   end
    #
    class Update
      include Dry::Monads[:result]
      include Import[
        race_repo: "repos.race"
      ]

      # @param id [Integer] Race ID
      # @param params [Hash] Updated attributes
      # @return [Dry::Monads::Result] Success(Structs::Race) or Failure(errors)
      def call(id:, **params)
        # Find existing race
        existing_race = race_repo.find(id)
        return Failure(not_found: "Race not found") unless existing_race

        # Check business rules
        return Failure(completed: "Cannot edit completed races") if existing_race.completed?

        # Validate input
        contract = Operations::Contracts::UpdateRace.new
        validation = contract.call(params)

        return Failure(validation.errors.to_h) unless validation.success?

        # Prepare attributes
        attrs = validation.to_h

        # Recompute stage_name if stage_type or heat_number changed
        if attrs.key?(:stage_type) || attrs.key?(:heat_number)
          stage_type = attrs[:stage_type] || existing_race.stage_type
          heat_number = attrs.key?(:heat_number) ? attrs[:heat_number] : existing_race.heat_number
          attrs[:stage_name] = compute_stage_name(stage_type, heat_number)
        end

        # Update race via injected repo
        updated_race = race_repo.update(id, attrs)

        Success(updated_race)
      rescue ActiveRecord::RecordInvalid => e
        Failure(database: e.message)
      rescue ActiveRecord::RecordNotFound
        Failure(not_found: "Race not found")
      rescue StandardError => e
        Failure(unexpected: e.message)
      end

      private

      # Compute stage_name from stage_type and heat_number
      # @param stage_type [String]
      # @param heat_number [Integer, nil]
      # @return [String]
      def compute_stage_name(stage_type, heat_number)
        if heat_number.present?
          "#{stage_type} #{heat_number}"
        else
          stage_type
        end
      end
    end
  end
end