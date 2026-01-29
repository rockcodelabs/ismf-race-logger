# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module Operations
  module Athletes
    # Operation for bulk importing athletes into a race
    #
    # This operation orchestrates the entire athlete import process:
    # 1. Validates the JSON structure
    # 2. Finds or creates each athlete
    # 3. Creates race participations
    # 4. Collects errors and statistics
    #
    # Example:
    #   operation = Operations::Athletes::BulkImport.new
    #   result = operation.call(
    #     race_id: 1,
    #     athletes_json: '[{"bib_number": 1, "first_name": "John", ...}]'
    #   )
    #
    #   if result.success?
    #     summary = result.value!
    #     puts summary.summary_message
    #   else
    #     errors = result.failure
    #     puts errors
    #   end
    #
    class BulkImport
      include Dry::Monads[:result, :do]
      include Dry::Monads::Do.for(:call)

      # Initialize with dependencies
      #
      # @param athlete_repo [DB::AthleteRepo]
      # @param participation_repo [DB::RaceParticipationRepo]
      # @param contract [Operations::Contracts::BulkImportAthletes]
      def initialize(
        athlete_repo: AthleteRepo.new,
        participation_repo: RaceParticipationRepo.new,
        contract: Operations::Contracts::BulkImportAthletes.new
      )
        @athlete_repo = athlete_repo
        @participation_repo = participation_repo
        @contract = contract
      end

      # Execute the bulk import
      #
      # @param race_id [Integer] ID of the race to import athletes into
      # @param athletes_json [String] JSON string containing array of athletes
      # @return [Dry::Monads::Result<Structs::AthleteImportResult, Hash>]
      def call(race_id:, athletes_json:)
        athletes_data = yield parse_json(athletes_json)
        validated = yield validate_input(race_id: race_id, athletes: athletes_data)
        result = yield process_import(race_id: validated[:race_id], athletes: validated[:athletes])

        Success(result)
      end

      private

      attr_reader :athlete_repo, :participation_repo, :contract

      # Parse JSON string into Ruby array
      #
      # @param json_string [String]
      # @return [Dry::Monads::Result<Array, String>]
      def parse_json(json_string)
        athletes = JSON.parse(json_string, symbolize_names: true)
        Success(athletes)
      rescue JSON::ParserError => e
        Failure("Invalid JSON format: #{e.message}")
      end

      # Validate input using contract
      #
      # @param race_id [Integer]
      # @param athletes [Array<Hash>]
      # @return [Dry::Monads::Result<Hash, Hash>]
      def validate_input(race_id:, athletes:)
        validation = contract.call(race_id: race_id, athletes: athletes)

        if validation.success?
          Success(validation.to_h)
        else
          Failure(validation.errors.to_h)
        end
      end

      # Process the import for all athletes
      #
      # @param race_id [Integer]
      # @param athletes [Array<Hash>]
      # @return [Dry::Monads::Result<Structs::AthleteImportResult>]
      def process_import(race_id:, athletes:)
        new_athletes_count = 0
        existing_athletes_count = 0
        participations_created = 0
        errors = []

        athletes.each do |athlete_data|
          result = import_single_athlete(race_id: race_id, athlete_data: athlete_data)

          if result.success?
            info = result.value!
            if info[:new_athlete]
              new_athletes_count += 1
            else
              existing_athletes_count += 1
            end
            participations_created += 1
          else
            error_msg = "Bib #{athlete_data[:bib_number]} (#{athlete_data[:first_name]} #{athlete_data[:last_name]}): #{result.failure}"
            errors << error_msg
          end
        end

        # If there are errors, return them
        if errors.any?
          return Failure(errors: errors, partial_success: participations_created > 0)
        end

        # Success - return summary
        Success(
          Structs::AthleteImportResult.new(
            total_count: participations_created,
            new_athletes_count: new_athletes_count,
            existing_athletes_count: existing_athletes_count,
            participations_created: participations_created,
            errors: []
          )
        )
      end

      # Import a single athlete and create participation
      #
      # @param race_id [Integer]
      # @param athlete_data [Hash] {:bib_number, :first_name, :last_name, :gender, :country, :license_number?}
      # @return [Dry::Monads::Result<Hash, String>]
      def import_single_athlete(race_id:, athlete_data:)
        # Find or create athlete
        athlete, created = athlete_repo.find_or_create_by(
          first_name: athlete_data[:first_name],
          last_name: athlete_data[:last_name],
          gender: athlete_data[:gender],
          country: athlete_data[:country],
          license_number: athlete_data[:license_number]
        )

        # Create race participation
        result = participation_repo.create_for_import(
          race_id: race_id,
          athlete_id: athlete.id,
          bib_number: athlete_data[:bib_number]
        )

        if result.success?
          Success(athlete: athlete, new_athlete: created)
        else
          Failure(result.failure)
        end
      rescue StandardError => e
        Failure(e.message)
      end
    end
  end
end