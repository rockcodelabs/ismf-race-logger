# frozen_string_literal: true

module Structs
  # Immutable domain object representing a Race Participation
  #
  # This struct links an athlete to a race with their bib number and race status.
  # Used for displaying race entries, results, and tracking athlete participation.
  #
  # Example:
  #   participation = race_participation_repo.find(1)
  #   participation.display_name # => "001 - John DOE (ITA)"
  #   participation.can_report? # => true
  #
  class RaceParticipation < DB::Struct
    attribute :id, Types::Integer
    attribute :race_id, Types::Integer
    attribute :athlete_id, Types::Integer
    attribute :team_id, Types::Integer.optional
    attribute :bib_number, Types::BibNumber
    attribute :heat, Types::String.optional
    attribute :active_in_heat, Types::Bool
    attribute :status, Types::ParticipationStatus
    attribute :start_time, Types::OptionalDateTime
    attribute :finish_time, Types::OptionalDateTime
    attribute :rank, Types::Integer.optional
    attribute :created_at, Types::OptionalDateTime
    attribute :updated_at, Types::OptionalDateTime

    # Nested athlete struct (optional - can be nil if not loaded)
    attribute :athlete, Structs::Athlete.optional.default(nil)

    # Nested team struct (optional - can be nil if individual race)
    attribute :team, Types::Any.optional.default(nil) # Will be Structs::Team when implemented

    # Returns display name with bib number and athlete
    #
    # @return [String] "001 - John DOE (ITA)"
    def display_name
      if athlete
        "#{bib_display} - #{athlete.display_name}"
      else
        bib_display
      end
    end

    # Returns formatted bib number (3 digits with leading zeros)
    #
    # @return [String] "001"
    def bib_display
      bib_number.to_s.rjust(3, "0")
    end

    # Returns country from athlete or team
    #
    # @return [String, nil] "ITA"
    def country
      athlete&.country || team&.country
    end

    # Checks if this is a team race
    #
    # @return [Boolean]
    def team_race?
      !team_id.nil?
    end

    # Checks if athlete can be reported (active and not finished)
    #
    # @return [Boolean]
    def can_report?
      active_in_heat && status != "finished" && status != "dns"
    end

    # Checks if athlete has started
    #
    # @return [Boolean]
    def started?
      !start_time.nil?
    end

    # Checks if athlete has finished
    #
    # @return [Boolean]
    def finished?
      status == "finished" && !finish_time.nil?
    end

    # Checks if athlete did not start
    #
    # @return [Boolean]
    def dns?
      status == "dns"
    end

    # Checks if athlete did not finish
    #
    # @return [Boolean]
    def dnf?
      status == "dnf"
    end

    # Checks if athlete was disqualified
    #
    # @return [Boolean]
    def disqualified?
      status == "dsq"
    end
  end
end