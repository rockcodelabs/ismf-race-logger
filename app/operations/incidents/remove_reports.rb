# frozen_string_literal: true

module Operations
  module Incidents
    # Remove Reports Operation
    #
    # Removes one or more reports from an incident.
    # Reports are unlinked and returned to pending_review status for VAR to re-organize.
    #
    # This operation:
    # 1. Validates the incident exists
    # 2. Validates all reports exist and belong to this incident
    # 3. Unlinks reports from the incident (sets incident_id to nil)
    # 4. Returns reports to pending_review status
    # 5. Returns the updated incident struct
    #
    # Returns:
    # - Success(Structs::Incident) if reports removed successfully
    # - Failure(:incident_not_found) if incident doesn't exist
    # - Failure(:reports_not_found, ids) if some reports don't exist
    # - Failure(:reports_not_in_incident, ids) if reports don't belong to this incident
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Incidents::RemoveReports.new.call(
    #     incident_id: 5,
    #     report_ids: [10, 11]
    #   )
    #
    #   result.success?                # => true
    #   result.value!.reports_count    # => 3 (was 5, removed 2)
    #
    class RemoveReports
      include Dry::Monads[:result]

      def initialize(incident_repo: IncidentRepo.new)
        @incident_repo = incident_repo
      end

      def call(incident_id:, report_ids:)
        # Ensure report_ids is an array
        report_ids = Array(report_ids)
        return Failure([:no_reports_provided, "No report IDs provided"]) if report_ids.empty?

        # Find the incident
        incident = Incident.find_by(id: incident_id)
        return Failure(:incident_not_found) unless incident

        # Load all reports
        reports = Report.where(id: report_ids)
        found_ids = reports.pluck(:id)
        missing_ids = report_ids - found_ids

        return Failure([:reports_not_found, missing_ids]) if missing_ids.any?

        # Check if all reports belong to this incident
        not_in_incident = reports.where.not(incident_id: incident_id)
        if not_in_incident.any?
          wrong_ids = not_in_incident.pluck(:id)
          return Failure([:reports_not_in_incident, wrong_ids])
        end

        # Unlink reports from incident and reset to pending_review
        ActiveRecord::Base.transaction do
          reports.update_all(
            incident_id: nil,
            status: "pending_review",
            updated_at: Time.current
          )
        end

        # Return updated incident struct
        Success(@incident_repo.find(incident.id))
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end