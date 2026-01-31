# frozen_string_literal: true

module Structs
  # IncidentSummary Data Struct
  #
  # Lightweight summary for incident lists and collections.
  # Uses Ruby Data.define for fast instantiation in collections.
  #
  # Used for:
  # - Admin incident index pages
  # - Touch display incident lists
  # - Recent incidents display
  #
  IncidentSummary = Data.define(
    :id,
    :race_id,
    :race_location_id,
    :race_location_name,
    :status,
    :reports_count,
    :penalties_count,
    :bib_numbers,
    :created_at
  ) do
    # Check if incident is pending decision
    def pending?
      status == "pending"
    end

    # Check if incident was approved
    def approved?
      status == "approved"
    end

    # Check if incident was rejected
    def rejected?
      status == "rejected"
    end

    # Returns CSS class for status badge
    def status_badge_class
      case status
      when "pending" then "bg-yellow-100 text-yellow-800"
      when "approved" then "bg-green-100 text-green-800"
      when "rejected" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    end

    # Returns human-readable status label
    def status_label
      status.titleize
    end

    # Returns display string for bib numbers
    # e.g., "12, 25" or "12" or "—"
    def bib_display
      return "—" if bib_numbers.nil? || bib_numbers.empty?

      bib_numbers.join(", ")
    end

    # Returns location name or placeholder
    def location_display
      race_location_name.presence || "Unknown"
    end

    # Check if incident has penalties attached
    def has_penalties?
      penalties_count.to_i > 0
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
  end
end
