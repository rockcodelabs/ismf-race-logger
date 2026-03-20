# frozen_string_literal: true

module Operations
  module Contracts
    # CreateReport Contract
    #
    # Validates input parameters for creating a report during a race.
    # Reports are quick captures of potential incidents (location + bib).
    #
    # Required fields:
    # - race_id: integer (must be an in_progress race)
    # - race_location_id: integer (must belong to the race)
    # - race_participation_id: integer (must belong to the race)
    # - bib_number: integer (denormalized for quick display)
    # - user_id: integer (who created the report)
    #
    # Optional fields:
    # - athlete_position: integer (1 or 2 for team races)
    # - description: string (notes about what happened)
    # - client_uuid: string (for offline sync/idempotency)
    #
    class CreateReport < Dry::Validation::Contract
      params do
        required(:race_id).filled(:integer)
        required(:race_location_id).filled(:integer)
        optional(:race_participation_id).maybe(:integer)
        optional(:bib_number).maybe(:integer)
        required(:user_id).filled(:integer)
        optional(:athlete_position).maybe(:integer)
        optional(:description).maybe(:string)
        optional(:client_uuid).maybe(:string)
      end

      # Validate race exists and is in progress (bypassed for test races)
      rule(:race_id) do
        race = Race.find_by(id: value)
        if race.nil?
          key.failure("must be a valid race")
        elsif race.status != "in_progress" && !race.is_test?
          key.failure("race must be in progress to create reports")
        end
      end

      # Validate race_location belongs to the race
      rule(:race_location_id, :race_id) do
        next unless values[:race_id] && values[:race_location_id]

        location = RaceLocation.find_by(id: values[:race_location_id])
        if location.nil?
          key(:race_location_id).failure("must be a valid race location")
        elsif location.race_id != values[:race_id]
          key(:race_location_id).failure("must belong to the specified race")
        end
      end

      # Validate race_participation belongs to the race (if provided)
      rule(:race_participation_id, :race_id) do
        next unless values[:race_id] && values[:race_participation_id].present?

        participation = RaceParticipation.find_by(id: values[:race_participation_id])
        if participation.nil?
          key(:race_participation_id).failure("must be a valid race participation")
        elsif participation.race_id != values[:race_id]
          key(:race_participation_id).failure("must belong to the specified race")
        end
      end

      # Validate bib_number is valid (if provided)
      rule(:bib_number) do
        next if value.nil?
        
        key.failure("must be between 1 and 9999") unless value.between?(1, 9999)
      end

      # Validate user exists
      rule(:user_id) do
        key.failure("must be a valid user") unless User.exists?(value)
      end

      # Validate athlete_position if provided (1 or 2 for team races)
      rule(:athlete_position) do
        next if value.nil?

        key.failure("must be 1 or 2") unless [ 1, 2 ].include?(value)
      end

      # Validate client_uuid format if provided
      rule(:client_uuid) do
        next if value.nil?

        uuid_format = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
        key.failure("must be a valid UUID format") unless value.match?(uuid_format)
      end
    end
  end
end
