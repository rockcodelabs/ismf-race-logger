# frozen_string_literal: true

module Web
  module Parts
    # Presentation logic for Incident in views
    #
    # Wraps Structs::Incident and Structs::IncidentSummary with view-specific methods.
    # Keeps structs pure (domain only) and templates simple (no inline logic).
    #
    # Example:
    #   part = Web::Parts::Incident.new(incident_struct)
    #   part.status_badge          # => { class: "bg-yellow-100 text-yellow-800", label: "Pending" }
    #   part.time_ago_in_words     # => "5 minutes ago"
    #   part.status                # Delegated to struct
    #
    class Incident < Base
      # Badge configuration for status display
      def status_badge
        case value.status
        when "pending"
          { class: "bg-yellow-100 text-yellow-800", label: "Pending" }
        when "approved"
          { class: "bg-green-100 text-green-800", label: "Approved" }
        when "rejected"
          { class: "bg-red-100 text-red-800", label: "Rejected" }
        else
          { class: "bg-gray-100 text-gray-800", label: value.status.to_s.titleize }
        end
      end

      # Touch-friendly status badge (larger for touch displays)
      def touch_status_badge
        case value.status
        when "pending"
          { class: "bg-yellow-500 text-white", label: "Pending" }
        when "approved"
          { class: "bg-green-500 text-white", label: "Approved" }
        when "rejected"
          { class: "bg-red-500 text-white", label: "Rejected" }
        else
          { class: "bg-gray-500 text-white", label: value.status.to_s.titleize }
        end
      end

      # Time ago in words using Rails helper
      def time_ago_in_words
        helpers.time_ago_in_words(value.created_at)
      end

      # Formatted creation date
      def created_at_formatted
        value.created_at.strftime("%b %d, %Y %H:%M")
      end

      # Formatted decision date (if decided)
      def decided_at_formatted
        return nil unless value.respond_to?(:decided_at) && value.decided_at

        value.decided_at.strftime("%b %d, %Y %H:%M")
      end

      # DOM ID for Turbo Stream targeting
      def dom_id
        "incident_#{value.id}"
      end

      # Display string for location
      def location_display
        if value.respond_to?(:race_location_name) && value.race_location_name.present?
          value.race_location_name
        else
          "Unknown Location"
        end
      end

      # Display string for bib numbers (for summary)
      def bib_display
        if value.respond_to?(:bib_numbers) && value.bib_numbers.present?
          value.bib_numbers.join(", ")
        else
          "—"
        end
      end

      # Display string for reports count
      def reports_count_display
        count = value.respond_to?(:reports_count) ? value.reports_count.to_i : 0
        "#{count} #{count == 1 ? 'report' : 'reports'}"
      end

      # Display string for penalties count
      def penalties_count_display
        count = value.respond_to?(:penalties_count) ? value.penalties_count.to_i : 0
        return "No penalties" if count.zero?

        "#{count} #{count == 1 ? 'penalty' : 'penalties'}"
      end

      # Check if incident has penalties
      def has_penalties?
        value.respond_to?(:penalties_count) && value.penalties_count.to_i > 0
      end

      # Decision maker display
      def decided_by_display
        if value.respond_to?(:decided_by_user_name) && value.decided_by_user_name.present?
          value.decided_by_user_name
        else
          nil
        end
      end

      # CSS classes for the card/row based on status
      def card_class
        case value.status
        when "pending"
          "border-l-4 border-l-yellow-500"
        when "approved"
          "border-l-4 border-l-green-500"
        when "rejected"
          "border-l-4 border-l-red-500"
        else
          "border-l-4 border-l-gray-300"
        end
      end

      # Icon name for status (for icon display)
      def status_icon
        case value.status
        when "pending"
          "clock"
        when "approved"
          "check-circle"
        when "rejected"
          "x-circle"
        else
          "question-mark-circle"
        end
      end

      # Action buttons to show based on status
      def available_actions
        actions = []
        if value.respond_to?(:pending?) && value.pending?
          actions << :decide
        end
        if value.respond_to?(:can_reopen?) && value.can_reopen?
          actions << :reopen
        end
        actions << :view
        actions
      end

      # Display name for incident (custom_name or fallback to ID)
      def display_name
        if value.respond_to?(:custom_name) && value.custom_name.present?
          value.custom_name
        else
          "Incident ##{value.id}"
        end
      end

      # Combined time, location, and reporters display
      def time_location_reporters_display
        parts = []
        
        # Add time with seconds
        if value.respond_to?(:created_at_with_seconds)
          parts << value.created_at_with_seconds
        elsif value.respond_to?(:created_at)
          parts << value.created_at.strftime("%H:%M:%S")
        end
        
        # Add location
        parts << location_display
        
        # Add reporters
        if value.respond_to?(:reporters_display)
          parts << "by #{value.reporters_display}"
        end
        
        parts.join(" • ")
      end

      # Formatted time with seconds
      def created_at_with_seconds
        if value.respond_to?(:created_at_with_seconds)
          value.created_at_with_seconds
        elsif value.respond_to?(:created_at)
          value.created_at.strftime("%H:%M:%S")
        else
          "—"
        end
      end

      # Reporter names display
      def reporters_display
        if value.respond_to?(:reporters_display)
          value.reporters_display
        else
          "Unknown"
        end
      end

      # Penalties display (shows first penalty or count)
      def penalties_display
        if value.respond_to?(:penalties_display)
          value.penalties_display
        elsif value.respond_to?(:penalties_count) && value.penalties_count.to_i > 0
          "#{value.penalties_count} #{value.penalties_count == 1 ? 'penalty' : 'penalties'}"
        else
          nil
        end
      end

      # Penalties tooltip (all penalty details for hover)
      def penalties_tooltip
        if value.respond_to?(:penalties_tooltip)
          value.penalties_tooltip
        else
          nil
        end
      end

      # Athletes display with country flags
      def athletes_with_flags
        return "—" if !value.respond_to?(:athletes) || value.athletes.nil? || value.athletes.empty?
        
        value.athletes.map do |athlete|
          country_flag = country_flag_emoji(athlete[:country])
          "#{athlete[:first_name]} #{athlete[:last_name]} #{country_flag}"
        end.join(", ")
      end

      # Simple athlete names display (no flags)
      def athletes_display
        if value.respond_to?(:athletes_display)
          value.athletes_display
        else
          "—"
        end
      end

      # Get athlete countries (unique)
      def athlete_countries
        if value.respond_to?(:athlete_countries)
          value.athlete_countries
        else
          []
        end
      end

      # Convert country code to flag emoji using ISO3166 gem
      def country_flag_emoji(country_code)
        return "" if country_code.nil? || country_code.empty?
        
        ISO3166::Country.find_country_by_alpha3(country_code)&.emoji_flag || ""
      end
    end
  end
end
