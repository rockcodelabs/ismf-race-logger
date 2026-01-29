# frozen_string_literal: true

module Structs
  # Full Competition struct for single record operations
  #
  # Used by: find, find!, find_by, create, update
  # Performance: dry-struct with full type validation and coercion
  #
  # Example:
  #   competition = Structs::Competition.new(
  #     id: 1,
  #     name: "World Cup Verbier 2024",
  #     city: "Verbier",
  #     place: "Swiss Alps",
  #     country: "CHE",
  #     description: "Annual World Cup competition...",
  #     start_date: Date.new(2024, 1, 15),
  #     end_date: Date.new(2024, 1, 17),
  #     webpage_url: "https://www.ismf-ski.org"
  #   )
  #
  #   competition.display_name    # => "Verbier 2024"
  #   competition.date_range       # => "Jan 15 - Jan 17, 2024"
  #   competition.ongoing?         # => true/false
  #
  class Competition < DB::Struct
    # Required attributes
    attribute :id, Types::Integer
    attribute :name, Types::String
    attribute :city, Types::String
    attribute :place, Types::String
    attribute :country, Types::CountryCode
    attribute :description, Types::String
    attribute :start_date, Types::Date
    attribute :end_date, Types::Date
    attribute :webpage_url, Types::String
    attribute :created_at, Types::FlexibleDateTime
    attribute :updated_at, Types::FlexibleDateTime

    # Optional attributes
    attribute? :logo_url, Types::String.optional

    # =========================================================================
    # Display methods
    # =========================================================================

    def display_name
      "#{city} #{start_date.year}"
    end

    def date_range
      "#{start_date.strftime('%b %d')} - #{end_date.strftime('%b %d, %Y')}"
    end

    def short_date_range
      if start_date.month == end_date.month
        "#{start_date.strftime('%b %d')}-#{end_date.day}, #{end_date.year}"
      else
        "#{start_date.strftime('%b %d')} - #{end_date.strftime('%b %d, %Y')}"
      end
    end

    # =========================================================================
    # Status predicates
    # =========================================================================

    def ongoing?
      Date.current.between?(start_date, end_date)
    end

    def upcoming?
      start_date > Date.current
    end

    def past?
      end_date < Date.current
    end

    def status
      return "ongoing" if ongoing?
      return "upcoming" if upcoming?
      "past"
    end

    def status_badge_class
      case status
      when "ongoing"
        "bg-green-100 text-green-800"
      when "upcoming"
        "bg-blue-100 text-blue-800"
      when "past"
        "bg-gray-100 text-gray-800"
      end
    end

    # =========================================================================
    # Country display
    # =========================================================================

    def country_name
      ISO3166::Country.find_country_by_alpha3(country)&.iso_short_name || country
    end

    def country_flag_emoji
      ISO3166::Country.find_country_by_alpha3(country)&.emoji_flag || ""
    end

    # =========================================================================
    # Duration calculations
    # =========================================================================

    def duration_days
      (end_date - start_date).to_i + 1
    end

    def days_until_start
      (start_date - Date.current).to_i
    end

    def days_since_end
      (Date.current - end_date).to_i
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
  end
end