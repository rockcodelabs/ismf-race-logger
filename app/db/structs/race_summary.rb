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
    :stage_type,
    :stage_name,
    :position,
    :scheduled_at,
    :status,
    :race_type_name
  ) do
    # Display name is just the race name
    def display_name
      name
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

    def can_edit?
      !completed?
    end

    # Time formatting
    def formatted_scheduled_time
      return "Not scheduled" unless scheduled_at.present?
      scheduled_at.strftime("%H:%M")
    end

    def formatted_scheduled_date
      return "Not scheduled" unless scheduled_at.present?
      scheduled_at.strftime("%b %d, %Y")
    end

    def scheduled_today?
      scheduled_at.present? && scheduled_at.to_date == Date.current
    end

    # Badge styling for status
    def status_badge_class
      case status
      when "scheduled"
        "bg-blue-100 text-blue-800"
      when "in_progress"
        "bg-green-100 text-green-800 animate-pulse"
      when "completed"
        "bg-gray-100 text-gray-800"
      when "cancelled"
        "bg-red-100 text-red-800"
      else
        "bg-gray-100 text-gray-800"
      end
    end

    def status_text
      status.titleize
    end

    # =========================================================================
    # Rails URL helper compatibility
    # =========================================================================

    # Required for form_with and link_to to work with structs
    def to_model
      self
    end

    # Required for form URL generation
    def persisted?
      id.present?
    end

    def new_record?
      !persisted?
    end

    # Required for Rails URL helpers (link_to, form_with, etc.)
    def to_param
      id.to_s
    end

    # Required for Pundit to find the correct policy
    def model_name
      ::Race.model_name
    end

    # Required for Pundit policy lookup
    def policy_class
      RacePolicy
    end
  end
end