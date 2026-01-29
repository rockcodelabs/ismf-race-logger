# frozen_string_literal: true

module Structs
  # Lightweight Competition summary for collection operations
  #
  # Used by: all, where, search, upcoming, ongoing, past
  # Performance: Ruby Data class (7x faster than dry-struct)
  #
  # This struct contains minimal attributes needed for list views.
  # For full competition details, use Structs::Competition via find/find_by.
  #
  # Example:
  #   summary = Structs::CompetitionSummary.new(
  #     id: 1,
  #     name: "World Cup Verbier 2024",
  #     city: "Verbier",
  #     place: "Swiss Alps",
  #     country: "CHE",
  #     start_date: Date.new(2024, 1, 15),
  #     end_date: Date.new(2024, 1, 17),
  #     created_at: Time.current
  #   )
  #
  #   summary.display_name    # => "Verbier 2024"
  #   summary.status          # => "ongoing"
  #   summary.ongoing?        # => true/false
  #
  CompetitionSummary = Data.define(
    :id,
    :name,
    :city,
    :place,
    :country,
    :start_date,
    :end_date,
    :created_at
  ) do
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
    # Rails routing compatibility
    # =========================================================================

    # Returns the ID as a string for Rails URL helpers
    # This enables using Data.define structs directly with path helpers like:
    #   admin_competition_path(competition_summary)
    #   edit_admin_competition_path(competition_summary)
    def to_param
      id.to_s
    end
  end
end