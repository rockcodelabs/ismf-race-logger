# frozen_string_literal: true

module Structs
  # Summary Race struct for collections (lighter than full struct)
  #
  # Used by: all, where, many (collection queries)
  # Performance: Ruby Data.define (fast, immutable)
  #
  # Example:
  #   races = race_repo.for_competition(competition_id)
  #   # => [Structs::RaceSummary, Structs::RaceSummary, ...]
  #
  #   races.each do |race|
  #     puts race.display_name
  #     puts race.status
  #   end
  #
  RaceSummary = Data.define(
    :id,
    :competition_id,
    :race_type_id,
    :name,
    :stage,
    :start_time,
    :position,
    :status,
    :race_type_name
  ) do
    # Display name combining race type and stage
    def display_name
      "#{race_type_name&.titleize || 'Race'} - #{stage.titleize}"
    end

    # Short name with abbreviation
    def short_name
      "#{race_type_name&.titleize || 'Race'} #{stage_abbrev}"
    end

    # Stage abbreviation
    def stage_abbrev
      case stage
      when "qualification"
        "Q"
      when "semifinal"
        "SF"
      when "final"
        "F"
      else
        stage[0].upcase
      end
    end

    # Status predicates
    def scheduled?
      status == "scheduled"
    end

    def in_progress?
      status == "in_progress"
    end

    def completed?
      status == "completed"
    end

    def cancelled?
      status == "cancelled"
    end

    # Time formatting
    def formatted_start_time
      start_time.strftime("%H:%M")
    end

    # Badge styling for status
    def status_badge_class
      case status
      when "scheduled"
        "bg-blue-100 text-blue-800"
      when "in_progress"
        "bg-green-100 text-green-800"
      when "completed"
        "bg-gray-100 text-gray-800"
      when "cancelled"
        "bg-red-100 text-red-800"
      end
    end
  end
end