# frozen_string_literal: true

module Web
  module Parts
    # Presentation logic for Report in views
    #
    # Wraps Structs::Report and Structs::ReportSummary with view-specific methods.
    # Keeps structs pure (domain only) and templates simple (no inline logic).
    #
    # Example:
    #   part = Web::Parts::Report.new(report_struct)
    #   part.status_badge           # => { class: "bg-yellow-100 text-yellow-800", label: "Pending" }
    #   part.bib_number             # Delegated to struct
    #
    class Report < Base
      # Badge configuration for status display
      def status_badge
        case value.status
        when "pending_review"
          { class: "bg-yellow-100 text-yellow-800", label: "Pending" }
        when "confirmed"
          { class: "bg-blue-100 text-blue-800", label: "Confirmed" }
        when "rejected"
          { class: "bg-red-100 text-red-800", label: "Rejected" }
        else
          { class: "bg-gray-100 text-gray-800", label: value.status.titleize }
        end
      end

      # Touch-friendly status badge (larger)
      def touch_status_badge
        case value.status
        when "pending_review"
          { class: "bg-yellow-500 text-white", label: "Pending" }
        when "confirmed"
          { class: "bg-blue-500 text-white", label: "Confirmed" }
        when "rejected"
          { class: "bg-red-500 text-white", label: "Rejected" }
        else
          { class: "bg-gray-500 text-white", label: value.status.titleize }
        end
      end

      # Formatted bib display (handles team positions)
      def bib_badge
        if value.athlete_position.present? && value.athlete_position > 0
          position_label = value.athlete_position == 1 ? "A" : "B"
          "#{value.bib_number}#{position_label}"
        else
          value.bib_number.to_s
        end
      end

      # Short display for pending queue (e.g., "#12 @ Uphill-Top")
      def queue_display
        "##{value.bib_number} @ #{location_name}"
      end

      # Location name with fallback
      def location_name
        if value.respond_to?(:race_location_name) && value.race_location_name.present?
          value.race_location_name
        elsif value.respond_to?(:location_display)
          value.location_display
        else
          "Unknown"
        end
      end

      # Athlete name with flag and fallback
      def athlete_name_display
        if value.respond_to?(:athlete_display)
          value.athlete_display
        elsif value.respond_to?(:athlete_name) && value.athlete_name.present?
          # Fallback to plain name if athlete_display not available
          value.athlete_name
        else
          "Bib ##{value.bib_number}"
        end
      end

      # Formatted creation time
      def created_at_formatted
        value.created_at.strftime("%H:%M")
      end

      # Formatted creation time with date
      def created_at_full
        value.created_at.strftime("%b %d, %Y at %H:%M")
      end

      # Time ago in words (simple implementation)
      def time_ago
        seconds = Time.current - value.created_at
        case seconds
        when 0..59 then "just now"
        when 60..3599 then "#{(seconds / 60).to_i}m ago"
        when 3600..86_399 then "#{(seconds / 3600).to_i}h ago"
        else "#{(seconds / 86_400).to_i}d ago"
        end
      end

      # DOM ID for Turbo Stream targeting
      def dom_id
        "report_#{value.id}"
      end

      # Check if report can be confirmed
      def can_confirm?
        value.respond_to?(:can_confirm?) ? value.can_confirm? : value.status == "pending_review"
      end

      # Check if report can be rejected
      def can_reject?
        value.respond_to?(:can_reject?) ? value.can_reject? : value.status == "pending_review"
      end

      # Check if report can be reopened
      def can_reopen?
        value.respond_to?(:can_reopen?) ? value.can_reopen? : value.status != "pending_review"
      end

      # Check if report can be merged into incident
      def can_merge?
        if value.respond_to?(:can_merge?)
          value.can_merge?
        else
          value.status == "confirmed" && (value.respond_to?(:incident_id) ? value.incident_id.nil? : true)
        end
      end

      # Check if report is linked to incident
      def linked_to_incident?
        if value.respond_to?(:linked_to_incident?)
          value.linked_to_incident?
        elsif value.respond_to?(:incident_id)
          value.incident_id.present?
        else
          false
        end
      end

      # Row CSS classes based on status
      def row_class
        case value.status
        when "pending_review" then "bg-yellow-50"
        when "confirmed" then "bg-blue-50"
        when "rejected" then "bg-red-50"
        else ""
        end
      end

      # Touch card CSS classes based on status
      def touch_card_class
        base = "p-4 rounded-lg border-2 "
        case value.status
        when "pending_review" then base + "border-yellow-400 bg-yellow-50"
        when "confirmed" then base + "border-blue-400 bg-blue-50"
        when "rejected" then base + "border-red-400 bg-red-50"
        else base + "border-gray-400 bg-gray-50"
        end
      end
    end
  end
end
