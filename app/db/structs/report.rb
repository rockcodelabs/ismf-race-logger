# frozen_string_literal: true

module Structs
  # Report Struct
  #
  # Immutable domain object representing a report captured during a race.
  # Reports are quick captures (location + bib) that are later reviewed
  # and merged into incidents.
  #
  # Workflow:
  #   1. Create report (location + bib) during live race
  #   2. Review and confirm/reject
  #   3. Merge confirmed reports into incidents
  #
  # Used for:
  # - Single report detail views
  # - Report review workflow
  # - Report show pages
  #
  class Report < DB::Struct
    attribute :id, Types::Integer
    attribute :client_uuid, Types::UUID
    attribute :race_id, Types::Integer
    attribute :incident_id, Types::Integer.optional
    attribute :user_id, Types::Integer
    attribute :race_location_id, Types::Integer
    attribute :race_participation_id, Types::Integer
    attribute :bib_number, Types::BibNumber
    attribute :athlete_position, Types::Integer.optional
    attribute :description, Types::String.optional
    attribute :status, Types::ReportStatus
    attribute :created_at, Types::FlexibleDateTime
    attribute :updated_at, Types::FlexibleDateTime

    # Optional nested data (loaded via repo methods)
    attribute :race_location_name, Types::String.optional
    attribute :athlete_name, Types::String.optional
    attribute :athlete_country, Types::String.optional
    attribute :user_name, Types::String.optional

    # Status helpers
    def pending_review?
      status == "pending_review"
    end

    def confirmed?
      status == "confirmed"
    end

    def rejected?
      status == "rejected"
    end

    # Can this report be confirmed?
    def can_confirm?
      pending_review?
    end

    # Can this report be rejected?
    def can_reject?
      pending_review?
    end

    # Can this report be reopened?
    def can_reopen?
      !pending_review?
    end

    # Is this report linked to an incident?
    def has_incident?
      incident_id.present?
    end

    # Can this report be merged into an incident?
    def can_merge?
      confirmed? && !has_incident?
    end

    # Display the status with appropriate styling class
    def status_css_class
      case status
      when "pending_review" then "bg-yellow-100 text-yellow-800"
      when "confirmed" then "bg-blue-100 text-blue-800"
      when "rejected" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    end

    # Human-readable status
    def status_display
      case status
      when "pending_review" then "Pending Review"
      when "confirmed" then "Confirmed"
      when "rejected" then "Rejected"
      else status.titleize
      end
    end

    # Display bib number with athlete position for team races
    def bib_display
      if athlete_position.present? && athlete_position > 0
        "#{bib_number} (Athlete #{athlete_position})"
      else
        bib_number.to_s
      end
    end

    # Display location name
    def location_display
      race_location_name.presence || "Unknown"
    end

    # Display athlete name with flag
    def athlete_display
      if athlete_name.present?
        flag = athlete_country.present? ? country_flag(athlete_country) : ""
        "#{flag} #{athlete_name}".strip
      else
        "Bib ##{bib_number}"
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

    # Time since created (for display)
    def time_ago
      created_at
    end
  end
end
