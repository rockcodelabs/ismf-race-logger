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
    :custom_name,
    :status,
    :reports_count,
    :penalties_count,
    :penalty_details,
    :bib_numbers,
    :reporter_names,
    :athletes,
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

    # Returns display name (custom_name or "Incident #ID")
    def display_name
      custom_name.presence || "Incident ##{id}"
    end

    # Returns formatted reporter names
    def reporters_display
      return "Unknown" if reporter_names.nil? || reporter_names.empty?
      
      reporter_names.uniq.join(", ")
    end

    # Returns formatted time with seconds
    def created_at_with_seconds
      created_at.strftime("%H:%M:%S")
    end

    # Check if incident has penalties attached
    def has_penalties?
      penalties_count.to_i > 0
    end

    # Returns formatted penalty display (first penalty or count)
    def penalties_display
      return nil if penalty_details.nil? || penalty_details.empty?
      
      first_penalty = penalty_details.first
      if penalty_details.size == 1
        "#{first_penalty[:number]} - #{first_penalty[:name]}"
      else
        "#{penalty_details.size} penalties"
      end
    end

    # Returns tooltip text for penalties (all penalty details)
    def penalties_tooltip
      return nil if penalty_details.nil? || penalty_details.empty?
      
      penalty_details.map { |p| "#{p[:number]} - #{p[:name]}" }.join("\n")
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

    # Returns array of athlete full names
    def athlete_names
      return [] if athletes.nil? || athletes.empty?
      
      athletes.map { |a| "#{a[:first_name]} #{a[:last_name]}" }
    end

    # Returns array of athlete countries
    def athlete_countries
      return [] if athletes.nil? || athletes.empty?
      
      athletes.map { |a| a[:country] }.uniq
    end

    # Returns formatted athlete display with country flags
    # e.g., "John Doe 🇺🇸, Jane Smith 🇨🇦"
    def athletes_display
      return "—" if athletes.nil? || athletes.empty?
      
      athletes.map do |a|
        "#{a[:first_name]} #{a[:last_name]}"
      end.join(", ")
    end

    # Check if incident has athletes
    def has_athletes?
      athletes.present? && athletes.any?
    end
  end
end
