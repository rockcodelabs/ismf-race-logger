# frozen_string_literal: true

module Web
  module Parts
    # Presentation logic for {{Resource}}
    #
    # Parts wrap structs with view-specific logic. They:
    # - Keep structs pure (domain only)
    # - Keep templates simple (no inline logic)
    # - Are testable in isolation
    # - Delegate missing methods to the wrapped struct
    #
    # @example
    #   part = Web::Parts::{{Resource}}.new(struct)
    #   part.status_badge      # => presentation logic
    #   part.name              # => delegates to struct
    #   part.dom_id            # => "{{resource}}_123"
    #
    class {{Resource}} < Base
      # Presentation methods
      #
      # Good: formatting, badges, CSS classes, display strings, HTML helpers
      # Bad: business logic, database queries, state changes

      def status_badge
        case value.status
        when "active"
          helpers.tag.span("Active", class: "badge bg-green-100 text-green-800")
        when "pending"
          helpers.tag.span("Pending", class: "badge bg-yellow-100 text-yellow-800")
        when "inactive"
          helpers.tag.span("Inactive", class: "badge bg-gray-100 text-gray-800")
        else
          helpers.tag.span(value.status.titleize, class: "badge bg-gray-100 text-gray-800")
        end
      end

      def created_at_formatted
        value.created_at.strftime("%B %d, %Y")
      end

      def time_ago
        helpers.time_ago_in_words(value.created_at) + " ago"
      end

      def dom_id
        "{{resource}}_#{value.id}"
      end
    end
  end
end

# Placeholders:
#   {{Resource}} - Singular resource name (e.g., Incident)
#   {{resource}} - Lowercase singular (e.g., incident)