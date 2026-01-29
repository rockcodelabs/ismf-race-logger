# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module Operations
  module Athletes
    # Operation for copying participants from another race
    #
    # This operation copies all race participations from a source race
    # to a target race, preserving bib numbers and athlete assignments.
    #
    # Example:
    #   operation = Operations::Athletes::CopyParticipants.new
    #   result = operation.call(
    #     target_race_id: 5,
    #     source_race_id: 4
    #   )
    #
    #   if result.success?
    #     summary = result.value!
    #     puts "#{summary[:copied_count]} participants copied"
    #   else
    #     errors = result.failure
    #     puts errors
    #   end
    #
    class CopyParticipants
      include Dry::Monads[:result, :do]

      # Initialize with dependencies
      #
      # @param race_repo [RaceRepo]
      # @param participation_repo [RaceParticipationRepo]
      def initialize(
        race_repo: RaceRepo.new,
        participation_repo: RaceParticipationRepo.new
      )
        @race_repo = race_repo
        @participation_repo = participation_repo
      end

      # Execute the copy operation
      #
      # @param target_race_id [Integer] ID of the race to copy participants into
      # @param source_race_id [Integer] ID of the race to copy participants from
      # @return [Dry::Monads::Result<Hash, String>]
      def call(target_race_id:, source_race_id:)
        # Validate races exist
        target_race = race_repo.find(target_race_id)
        source_race = race_repo.find(source_race_id)

        return Failure("Target race not found") unless target_race
        return Failure("Source race not found") unless source_race
        
        # Validate gender categories match
        if target_race.gender_category != source_race.gender_category
          return Failure("Cannot copy participants: gender categories must match (source: #{source_race.gender_category_display}, target: #{target_race.gender_category_display})")
        end

        # Get source participations
        source_participations = participation_repo.for_race(source_race_id)

        if source_participations.empty?
          return Failure("Source race has no participants to copy")
        end

        # Copy each participation
        copied_count = 0
        skipped_count = 0
        errors = []

        source_participations.each do |source_participation|
          result = copy_single_participation(
            target_race_id: target_race_id,
            source_participation: source_participation
          )

          if result.success?
            copied_count += 1
          else
            skipped_count += 1
            errors << "Bib #{source_participation.bib_display}: #{result.failure}"
          end
        end

        # Return success if at least some were copied
        if copied_count > 0
          Success(
            copied_count: copied_count,
            skipped_count: skipped_count,
            total_count: source_participations.size,
            errors: errors
          )
        else
          Failure("Failed to copy any participants: #{errors.join(', ')}")
        end
      end

      private

      attr_reader :race_repo, :participation_repo

      # Copy a single participation to the target race
      #
      # @param target_race_id [Integer]
      # @param source_participation [Structs::RaceParticipation]
      # @return [Dry::Monads::Result]
      def copy_single_participation(target_race_id:, source_participation:)
        # Check if bib number is already taken
        existing_bib = participation_repo.find_by_bib(
          race_id: target_race_id,
          bib_number: source_participation.bib_number
        )

        if existing_bib
          return Failure("Bib number already taken")
        end

        # Check if athlete is already in the race
        existing_athlete = participation_repo.find_by_athlete(
          race_id: target_race_id,
          athlete_id: source_participation.athlete_id
        )

        if existing_athlete
          return Failure("Athlete already in race")
        end

        # Create new participation
        begin
          RaceParticipation.create!(
            race_id: target_race_id,
            athlete_id: source_participation.athlete_id,
            bib_number: source_participation.bib_number,
            status: "registered",
            active_in_heat: true
          )
          Success(true)
        rescue ActiveRecord::RecordInvalid => e
          Failure(e.message)
        end
      end
    end
  end
end