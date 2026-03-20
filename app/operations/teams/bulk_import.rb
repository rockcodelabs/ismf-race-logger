# frozen_string_literal: true

module Operations
  module Teams
    # Bulk import relay teams into a race
    #
    # Each team entry requires:
    # - bib_number: integer (team bib, same for both athletes)
    # - male:   { first_name, last_name, country, license_number? }
    # - female: { first_name, last_name, country, license_number? }
    # - team_name: string (optional, auto-generated if absent)
    #
    # One RaceParticipation is created per team (not per athlete).
    # Both athletes are stored on the Team record via athlete_1 (male) and athlete_2 (female).
    # Reports reference the team bib + athlete_position (1=male, 2=female).
    #
    # @example
    #   result = Operations::Teams::BulkImport.new.call(
    #     race_id: 1,
    #     teams_json: '[{"bib_number":1,"male":{...},"female":{...}}]'
    #   )
    #
    #   case result
    #   in Success(summary) then puts summary.summary_message
    #   in Failure(errors)  then puts errors
    #   end
    #
    class BulkImport
      include Dry::Monads[:result, :do]

      def initialize(
        athlete_repo: AthleteRepo.new,
        participation_repo: RaceParticipationRepo.new,
        contract: Operations::Contracts::BulkImportTeams.new
      )
        @athlete_repo = athlete_repo
        @participation_repo = participation_repo
        @contract = contract
      end

      # @param race_id [Integer]
      # @param teams_json [String] JSON array of team hashes
      # @return [Dry::Monads::Result]
      def call(race_id:, teams_json:)
        teams_data = yield parse_json(teams_json)
        validated  = yield validate_input(race_id: race_id, teams: teams_data)
        summary    = yield process_import(race_id: validated[:race_id], teams: validated[:teams])

        Success(summary)
      end

      private

      attr_reader :athlete_repo, :participation_repo, :contract

      # Parse JSON string → Ruby array
      def parse_json(json_string)
        data = JSON.parse(json_string, symbolize_names: true)
        Success(data)
      rescue JSON::ParserError => e
        Failure("Invalid JSON: #{e.message}")
      end

      # Validate via contract
      def validate_input(race_id:, teams:)
        result = contract.call(race_id: race_id, teams: teams)
        result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
      end

      # Process all teams
      def process_import(race_id:, teams:)
        created_count = 0
        new_athletes  = 0
        errors        = []

        teams.each do |team_data|
          result = import_team(race_id: race_id, team_data: team_data)

          if result.success?
            info = result.value!
            created_count += 1
            new_athletes  += info[:new_athletes_count]
          else
            errors << "Bib #{team_data[:bib_number]}: #{result.failure}"
          end
        end

        return Failure(errors: errors, partial_success: created_count > 0) if errors.any?

        Success(
          Structs::TeamImportResult.new(
            total_count:       created_count,
            new_athletes_count: new_athletes,
            errors:            []
          )
        )
      end

      # Import a single team:
      #   1. Find or create male athlete
      #   2. Find or create female athlete
      #   3. Create Team record
      #   4. Create one RaceParticipation for the team (bib = team bib, athlete = male)
      def import_team(race_id:, team_data:)
        new_athletes_count = 0

        ActiveRecord::Base.transaction do
          male_data   = team_data[:male]
          female_data = team_data[:female]
          bib         = team_data[:bib_number]

          # Find or create male athlete
          male, male_created = athlete_repo.find_or_create_by(
            first_name:     male_data[:first_name],
            last_name:      male_data[:last_name],
            gender:         "M",
            country:        male_data[:country],
            license_number: male_data[:license_number]
          )
          new_athletes_count += 1 if male_created

          # Find or create female athlete
          female, female_created = athlete_repo.find_or_create_by(
            first_name:     female_data[:first_name],
            last_name:      female_data[:last_name],
            gender:         "F",
            country:        female_data[:country],
            license_number: female_data[:license_number]
          )
          new_athletes_count += 1 if female_created

          # Auto-generate team name if not provided
          team_name = team_data[:team_name].presence ||
                      "#{male_data[:country]} Mixed #{bib}"

          # Create Team record
          team = Team.create!(
            race_id:   race_id,
            athlete_1: Athlete.find(male.id),
            athlete_2: Athlete.find(female.id),
            name:      team_name,
            team_type: "relay_team",
            bib_number: bib
          )

          # One RaceParticipation for the team (male as primary, team_id links both)
          participation_result = participation_repo.create_for_import(
            race_id:    race_id,
            athlete_id: male.id,
            bib_number: bib
          )

          unless participation_result.success?
            raise ActiveRecord::Rollback, participation_result.failure
          end

          # Link participation to team
          RaceParticipation
            .find_by(race_id: race_id, athlete_id: male.id, bib_number: bib)
            &.update!(team_id: team.id)

          Success(new_athletes_count: new_athletes_count)
        end
      rescue ActiveRecord::Rollback => e
        Failure(e.message.presence || "Transaction rolled back")
      rescue ActiveRecord::RecordInvalid => e
        Failure(e.message)
      rescue StandardError => e
        Failure(e.message)
      end
    end
  end
end