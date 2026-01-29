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
  #     name: "Women's Sprint - Qualification",
  #     stage_type: "qualification",
  #     heat_number: nil,
  #     stage_name: "Qualification",
  #     scheduled_at: Time.current + 2.hours,
  #     position: 1,
  #     status: "scheduled",
  #     race_type_name: "Sprint"
  #   )
  #
  #   race.display_name    # => "Sprint - Qualification"
  #   race.scheduled?      # => true
  #   race.in_progress?    # => false
  #
  class Race < DB::Struct
    # Required attributes
    attribute :id, Types::Integer
    attribute :competition_id, Types::Integer
    attribute :race_type_id, Types::Integer
    attribute :name, Types::String
    attribute :stage_type, Types::String
    attribute :stage_name, Types::String
    attribute :position, Types::Integer
    attribute :status, Types::RaceStatus
    attribute :gender_category, Types::GenderCategory
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    # Optional attributes
    attribute? :heat_number, Types::Integer.optional
    attribute? :scheduled_at, Types::Time.optional

    # Optional attributes (from joins/eager loading)
    attribute? :race_type_name, Types::String.optional
    attribute? :competition_name, Types::String.optional

    # =========================================================================
    # Display methods
    # =========================================================================

    def display_name
      name
    end

    def stage_display
      stage_name
    end

    def short_name
      "#{race_type_name&.titleize || 'Race'} #{stage_abbrev}"
    end

    def stage_abbrev
      case stage_type.downcase
      when "qualification"
        heat_number ? "Q#{heat_number}" : "Q"
      when "heat"
        heat_number ? "H#{heat_number}" : "H"
      when "quarterfinal"
        heat_number ? "QF#{heat_number}" : "QF"
      when "semifinal"
        heat_number ? "SF#{heat_number}" : "SF"
      when "final"
        heat_number ? "F#{heat_number}" : "F"
      else
        stage_type[0].upcase
      end
    end

    def full_stage_name
      if heat_number
        "#{stage_type.titleize} #{heat_number}"
      else
        stage_type.titleize
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
      scheduled? && scheduled_at.present? && scheduled_at <= Time.current
    end

    def can_report?
      in_progress?
    end

    def can_edit?
      !completed?
    end

    # =========================================================================
    # Time calculations
    # =========================================================================

    def started?
      !scheduled?
    end

    def upcoming?
      scheduled? && scheduled_at.present? && scheduled_at > Time.current
    end

    def scheduled_today?
      scheduled_at.present? && scheduled_at.to_date == Date.current
    end

    def minutes_until_start
      return 0 unless scheduled_at.present?
      return 0 if started?
      ((scheduled_at - Time.current) / 60).to_i
    end

    def formatted_scheduled_time
      return "Not scheduled" unless scheduled_at.present?
      scheduled_at.strftime("%H:%M")
    end

    def formatted_scheduled_datetime
      return "Not scheduled" unless scheduled_at.present?
      scheduled_at.strftime("%b %d, %Y %H:%M")
    end

    def formatted_scheduled_date
      return "Not scheduled" unless scheduled_at.present?
      scheduled_at.strftime("%b %d, %Y")
    end

    # =========================================================================
    # Gender category helpers
    # =========================================================================

    def gender_category_display
      case gender_category
      when "M" then "Men"
      when "W" then "Women"
      when "MM" then "Men's Team"
      when "WW" then "Women's Team"
      when "MW" then "Mixed Team"
      else gender_category
      end
    end

    def team_race?
      %w[MM WW MW].include?(gender_category)
    end

    def individual_race?
      %w[M W].include?(gender_category)
    end

    # =========================================================================
    # Badge styling (for Tailwind CSS)
    # =========================================================================

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
    # Rails form compatibility
    # =========================================================================

    # Required for form_with to work with structs
    # Returns self to allow form helpers to access struct attributes
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