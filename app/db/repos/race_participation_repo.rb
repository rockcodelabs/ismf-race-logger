# frozen_string_literal: true

# Repository for RaceParticipation data access
#
# This repo handles all database queries for race participations and returns
# immutable Structs::RaceParticipation objects.
#
# Example:
#   repo = RaceParticipationRepo.new
#   participation = repo.create_for_import(
#     race_id: 1,
#     athlete_id: 42,
#     bib_number: 1
#   )
#
class RaceParticipationRepo < DB::Repo
    returns_one :find_by_bib, :find_by_athlete
    returns_many :for_race, :active, :by_status

    # Find participation by race and bib number
    #
    # @param race_id [Integer]
    # @param bib_number [Integer]
    # @return [Structs::RaceParticipation, nil]
    def find_by_bib(race_id:, bib_number:)
      base_scope.find_by(race_id: race_id, bib_number: bib_number)
    end

    # Find participation by race and athlete
    #
    # @param race_id [Integer]
    # @param athlete_id [Integer]
    # @return [Structs::RaceParticipation, nil]
    def find_by_athlete(race_id:, athlete_id:)
      base_scope.find_by(race_id: race_id, athlete_id: athlete_id)
    end

    # Create race participation for import
    #
    # This method creates a new race participation and validates uniqueness.
    # Returns Success(participation) or Failure(error_message).
    #
    # @param race_id [Integer]
    # @param athlete_id [Integer]
    # @param bib_number [Integer]
    # @return [Dry::Monads::Result]
    def create_for_import(race_id:, athlete_id:, bib_number:)
      # Check if athlete already in race
      existing = find_by_athlete(race_id: race_id, athlete_id: athlete_id)
      if existing
        return Dry::Monads::Failure("Athlete already assigned to this race")
      end

      # Check if bib number already taken
      existing_bib = find_by_bib(race_id: race_id, bib_number: bib_number)
      if existing_bib
        return Dry::Monads::Failure("Bib number #{bib_number} already assigned")
      end

      # Create participation
      record = RaceParticipation.create!(
        race_id: race_id,
        athlete_id: athlete_id,
        bib_number: bib_number,
        status: "registered",
        active_in_heat: true
      )

      Dry::Monads::Success(build_struct(record))
    rescue ActiveRecord::RecordInvalid => e
      Dry::Monads::Failure(e.message)
    end

    # Get all participations for a race
    #
    # @param race_id [Integer]
    # @return [Array<Structs::RaceParticipation>]
    def for_race(race_id)
      base_scope
        .includes(:athlete)
        .where(race_id: race_id)
        .order(:bib_number)
        .map { |record| build_struct(record) }
    end

    # Get active participations (can still compete)
    #
    # @param race_id [Integer]
    # @return [Array<Structs::RaceParticipation>]
    def active(race_id)
      base_scope
        .where(race_id: race_id, active_in_heat: true)
        .where.not(status: ["dns", "finished"])
        .order(:bib_number)
        .map { |record| build_struct(record) }
    end

    # Get participations by status
    #
    # @param race_id [Integer]
    # @param status [String] "registered", "dns", "dnf", "dsq", "finished"
    # @return [Array<Structs::RaceParticipation>]
    def by_status(race_id, status)
      base_scope
        .where(race_id: race_id, status: status)
        .order(:bib_number)
        .map { |record| build_struct(record) }
    end

    protected

    def record_class
      RaceParticipation
    end

    def base_scope
      RaceParticipation.all
    end

    def build_struct(record)
      # Build athlete struct if loaded
      athlete_struct = if record.association(:athlete).loaded? && record.athlete
        Structs::Athlete.new(
          id: record.athlete.id,
          first_name: record.athlete.first_name,
          last_name: record.athlete.last_name,
          country: record.athlete.country,
          license_number: record.athlete.license_number,
          gender: record.athlete.gender,
          created_at: record.athlete.created_at,
          updated_at: record.athlete.updated_at
        )
      end

      Structs::RaceParticipation.new(
        id: record.id,
        race_id: record.race_id,
        athlete_id: record.athlete_id,
        team_id: record.team_id,
        bib_number: record.bib_number,
        heat: record.heat,
        active_in_heat: record.active_in_heat,
        status: record.status,
        start_time: record.start_time,
        finish_time: record.finish_time,
        rank: record.rank,
        created_at: record.created_at,
        updated_at: record.updated_at,
        athlete: athlete_struct
      )
    end

    def build_summary(record)
      build_struct(record)
    end
end