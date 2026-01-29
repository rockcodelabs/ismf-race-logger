# frozen_string_literal: true

module Structs
  # Full Race struct for single record operations
  #
  # Used by: find, find!, find_by, create, update
  # Performance: dry-struct with full type validation and coercion
  #
  # Example:
  #   race = Structs::Race.new(
  #     id: 1,
  #     competition_id: 1,
  #     race_type_id: 1,
  #     name: "Individual Qualification",
  #     stage: "qualification",
  #     start_time: Time.current + 2.hours,
  #     position: 1,
  #     status: "scheduled",
  #     race_type_name: "individual"
  #   )
  #
  #   race.display_name    # => "Individual - Qualification"
  #   race.scheduled?      # => true
  #   race.in_progress?    # => false
  #
  class Race < DB::Struct
    # Required attributes
    attribute :id, Types::Integer
    attribute :competition_id, Types::Integer
    attribute :race_type_id, Types::Integer
    attribute :name, Types::String
    attribute :stage, Types::RaceStage
    attribute :start_time, Types::FlexibleDateTime
    attribute :position, Types::Integer
    attribute :status, Types::RaceStatus
    attribute :created_at, Types::FlexibleDateTime
    attribute :updated_at, Types::FlexibleDateTime

    # Optional attributes (from joins/eager loading)
    attribute? :race_type_name, Types::String.optional

    # =========================================================================
    # Display methods
    # =========================================================================

    def display_name
      "#{race_type_name&.titleize || 'Race'} - #{stage.titleize}"
    end

    def stage_display
      stage.titleize
    end

    def short_name
      "#{race_type_name&.titleize || 'Race'} #{stage_abbrev}"
    end

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

    # =========================================================================
    # Status predicates
    # =========================================================================

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

    def can_start?
      scheduled? && start_time <= Time.current
    end

    def can_report?
      in_progress?
    end

    # =========================================================================
    # Time calculations
    # =========================================================================

    def started?
      !scheduled?
    end

    def upcoming?
      scheduled? && start_time > Time.current
    end

    def minutes_until_start
      return 0 if started?
      ((start_time - Time.current) / 60).to_i
    end

    def formatted_start_time
      start_time.strftime("%H:%M")
    end

    def formatted_start_datetime
      start_time.strftime("%b %d, %Y %H:%M")
    end

    # =========================================================================
    # Badge styling
    # =========================================================================

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