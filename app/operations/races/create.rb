# frozen_string_literal: true

module Operations
  module Races
    # Create a new race for a competition
    #
    # This operation:
    # - Validates input parameters
    # - Computes stage_name from stage_type and heat_number
    # - Auto-assigns position (last in race_type group)
    # - Creates the race record
    #
    # @example
    #   result = Operations::Races::Create.new.call(
    #     competition_id: 1,
    #     race_type_id: 3,
    #     name: "Women's Sprint - Qualification",
    #     stage_type: "Qualification",
    #     heat_number: nil,
    #     scheduled_at: Time.current + 2.hours
    #   )
    #
    #   case result
    #   in Success(race)
    #     # race is a Structs::Race
    #   in Failure(errors)
    #     # errors is a hash of validation errors
    #   end
    #
    class Create
      include Dry::Monads[:result]
      include Import[
        race_repo: "repos.race",
        populate_locations: "operations.races.populate_locations"
      ]

      # @param params [Hash] Input parameters
      # @return [Dry::Monads::Result] Success(Structs::Race) or Failure(errors)
      def call(params)
        # Validate input
        contract = Operations::Contracts::CreateRace.new
        validation = contract.call(params)

        return Failure(validation.errors.to_h) unless validation.success?

        # Prepare attributes
        attrs = validation.to_h
        attrs[:stage_name] = compute_stage_name(attrs[:stage_type], attrs[:heat_number])
        attrs[:position] = compute_position(attrs[:competition_id], attrs[:race_type_id])
        attrs[:status] ||= "scheduled"

        # Create race via injected repo
        created_race = race_repo.create(attrs)

        # Populate race locations from templates
        populate_result = populate_locations.call(
          race_id: created_race.id,
          race_type_id: created_race.race_type_id
        )
        
        # Log warning if population fails, but don't fail the entire operation
        # (race is already created; locations can be added manually if needed)
        if populate_result.failure?
          Rails.logger.warn("Failed to populate locations for race #{created_race.id}: #{populate_result.failure}")
        end

        Success(created_race)
      rescue ActiveRecord::RecordInvalid => e
        Failure(database: e.message)
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

      # Compute next position for race (last in race_type group)
      # @param competition_id [Integer]
      # @param race_type_id [Integer]
      # @return [Integer]
      def compute_position(competition_id, race_type_id)
        max_position = Race.where(
          competition_id: competition_id,
          race_type_id: race_type_id
        ).maximum(:position) || -1

        max_position + 1
      end
    end
  end
end