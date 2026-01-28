# frozen_string_literal: true

require "dry-types"

module IsmfRaceLogger
  # Shared type definitions for the application using dry-types.
  # Provides strict types, constrained types, and custom business types.
  module Types
    include Dry.Types()

    # Common types
    Email = String.constrained(format: URI::MailTo::EMAIL_REGEXP)
    StrictString = Strict::String.constrained(min_size: 1)
    UUID = String.constrained(
      format: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    )

    # User roles
    RoleName = Strict::String.enum(
      "var_operator",
      "national_referee",
      "international_referee",
      "jury_president",
      "referee_manager",
      "broadcast_viewer"
    )

    # Incident statuses
    IncidentStatus = Strict::String.enum("unofficial", "official")

    # Decision types
    DecisionType = Strict::String.enum(
      "pending",
      "penalty_applied",
      "rejected",
      "no_action"
    )

    # Race statuses
    RaceStatus = Strict::String.enum("upcoming", "active", "completed")

    # Bib number (1-9999)
    BibNumber = Coercible::Integer.constrained(gteq: 1, lteq: 9999)

    # Flexible DateTime type that accepts Time, DateTime, and ActiveSupport::TimeWithZone
    FlexibleDateTime = Nominal::Any.constructor { |value|
      case value
      when ::DateTime, ::Time
        value
      when nil
        nil
      else
        if defined?(::ActiveSupport::TimeWithZone) && value.is_a?(::ActiveSupport::TimeWithZone)
          value.to_datetime
        else
          DateTime.parse(value.to_s)
        end
      end
    }

    # Optional flexible datetime (allows nil)
    OptionalDateTime = FlexibleDateTime.optional
  end
end
