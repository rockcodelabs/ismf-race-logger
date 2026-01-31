# frozen_string_literal: true

module Structs
  # ReportSummary Data Struct
  #
  # Lightweight summary for report lists and collections.
  # Uses Ruby Data.define for fast instantiation in collections.
  #
  # Used for:
  # - Admin report index pages
  # - Touch display pending reports queue
  # - Report selection for merging into incidents
  #
  ReportSummary = Data.define(
    :id,
    :race_id,
    :incident_id,
    :bib_number,
    :athlete_position,
    :race_location_id,
    :race_location_name,
    :athlete_name,
    :athlete_country,
    :status,
    :created_at
  ) do
    # Check if report is pending review
    def pending_review?
      status == "pending_review"
    end

    # Check if report has been confirmed
    def confirmed?
      status == "confirmed"
    end

    # Check if report has been rejected
    def rejected?
      status == "rejected"
    end

    # Check if report is linked to an incident
    def linked_to_incident?
      !incident_id.nil?
    end

    # Can this report be merged into an incident?
    def can_merge?
      confirmed? && !linked_to_incident?
    end

    # Returns CSS class for status badge
    def status_badge_class
      case status
      when "pending_review" then "bg-yellow-100 text-yellow-800"
      when "confirmed" then "bg-blue-100 text-blue-800"
      when "rejected" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    end

    # Returns human-readable status label
    def status_label
      case status
      when "pending_review" then "Pending"
      when "confirmed" then "Confirmed"
      when "rejected" then "Rejected"
      else status.to_s.titleize
      end
    end

    # Returns bib display with position indicator for team races
    def bib_display
      if athlete_position && athlete_position > 0
        "#{bib_number} (#{athlete_position == 1 ? 'A' : 'B'})"
      else
        bib_number.to_s
      end
    end

    # Returns location name or placeholder
    def location_display
      race_location_name.presence || "Unknown"
    end

    # Returns athlete name with flag or placeholder
    def athlete_display
      if athlete_name.present?
        flag = athlete_country.present? ? country_flag(athlete_country) : ""
        "#{flag} #{athlete_name}".strip
      else
        "Unknown"
      end
    end

    # Convert ISO country code to flag emoji
    # @param country_code [String] ISO 3166-1 alpha-3 code (e.g., "ITA")
    # @return [String] Flag emoji
    def country_flag(country_code)
      return "" if country_code.blank?
      
      # Convert ISO 3166-1 alpha-3 to alpha-2 for flag emoji
      # This is a simplified mapping for common countries
      alpha2 = case country_code.upcase
      when "ITA" then "IT"
      when "FRA" then "FR"
      when "ESP" then "ES"
      when "SUI" then "CH"
      when "AUT" then "AT"
      when "GER" then "DE"
      when "USA" then "US"
      when "GBR" then "GB"
      when "CAN" then "CA"
      when "JPN" then "JP"
      when "CHN" then "CN"
      when "RUS" then "RU"
      when "NOR" then "NO"
      when "SWE" then "SE"
      when "FIN" then "FI"
      when "POL" then "PL"
      when "CZE" then "CZ"
      when "SVK" then "SK"
      when "SLO" then "SI"
      when "BEL" then "BE"
      when "NED" then "NL"
      else country_code[0..1] # Fallback: use first 2 letters
      end
      
      # Convert to flag emoji using regional indicator symbols
      alpha2.upcase.chars.map { |c| (c.ord + 127397).chr(Encoding::UTF_8) }.join
    end

    # Returns time ago in words (for display)
    # Note: This is a simple implementation; use Rails helper in views for full functionality
    def time_ago_display
      seconds = Time.current - created_at
      case seconds
      when 0..59 then "just now"
      when 60..3599 then "#{(seconds / 60).to_i}m ago"
      when 3600..86_399 then "#{(seconds / 3600).to_i}h ago"
      else "#{(seconds / 86_400).to_i}d ago"
      end
    end

    # Short display for pending queue (e.g., "#12 @ Uphill-Top")
    def queue_display
      "##{bib_number} @ #{location_display}"
    end
  end
end
