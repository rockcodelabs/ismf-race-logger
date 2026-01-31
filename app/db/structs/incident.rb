# frozen_string_literal: true

module Structs
  # Incident Struct
  #
  # Immutable domain object representing an incident created from merged reports.
  # Incidents receive decisions (approved/rejected) and can have penalties attached.
  #
  # Workflow:
  #   Reports (pending_review) → [Confirm/Merge] → Incident (pending) → [Decide] → (approved/rejected)
  #
  # Used for:
  # - Single incident detail views
  # - Incident decision workflow
  # - Incident show pages
  #
  class Incident < DB::Struct
    attribute :id, Types::Integer
    attribute :client_uuid, Types::UUID
    attribute :race_id, Types::Integer
    attribute :race_location_id, Types::Integer.optional
    attribute :status, Types::IncidentStatus
    attribute :description, Types::String.optional
    attribute :decided_by_user_id, Types::Integer.optional
    attribute :decided_at, Types::FlexibleDateTime.optional
    attribute :created_at, Types::FlexibleDateTime
    attribute :updated_at, Types::FlexibleDateTime

    # Optional nested data (loaded via repo methods)
    attribute :race_location_name, Types::String.optional
    attribute :decided_by_user_name, Types::String.optional
    attribute :reports_count, Types::Integer.optional
    attribute :penalties_count, Types::Integer.optional

    # Status helpers
    def pending?
      status == "pending"
    end

    def approved?
      status == "approved"
    end

    def rejected?
      status == "rejected"
    end

    # Can this incident be decided?
    def can_decide?
      pending?
    end

    # Can this incident be reopened?
    def can_reopen?
      !pending?
    end

    # Has this incident been decided?
    def decided?
      decided_at.present? && decided_by_user_id.present?
    end

    # Display the status with appropriate styling class
    def status_css_class
      case status
      when "pending" then "bg-yellow-100 text-yellow-800"
      when "approved" then "bg-green-100 text-green-800"
      when "rejected" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    end

    # Human-readable status
    def status_display
      status.titleize
    end

    # Time since created (for display)
    def time_ago
      created_at
    end
  end
end
