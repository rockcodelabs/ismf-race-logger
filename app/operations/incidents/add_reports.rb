# frozen_string_literal: true

module Operations
  module Incidents
    # Add Reports Operation
    #
    # Adds one or more reports to an existing incident.
    # This is used by VAR operators to merge pending reports into incidents.
    #
    # This operation:
    # 1. Validates the incident exists
    # 2. Validates all reports exist and are not already linked to other incidents
    # 3. Links all reports to the target incident
    # 4. Returns the updated incident struct
    #
    # Returns:
    # - Success(Structs::Incident) if reports added successfully
    # - Failure(:incident_not_found) if incident doesn't exist
    # - Failure(:reports_not_found, ids) if some reports don't exist
    # - Failure(:reports_already_linked, ids) if some reports are already in other incidents
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Incidents::AddReports.new.call(
    #     incident_id: 5,
    #     report_ids: [10, 11, 12]
    #   )
    #
    #   result.success?                # => true
    #   result.value!.reports_count    # => 5 (was 2, added 3)
    #
    class AddReports
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

        # Check if any reports are already linked to OTHER incidents
        already_linked = reports.where.not(incident_id: nil).where.not(incident_id: incident_id)
        if already_linked.any?
          linked_ids = already_linked.pluck(:id)
          return Failure([:reports_already_linked, linked_ids])
        end

        # Link all reports to this incident
        ActiveRecord::Base.transaction do
          reports.update_all(incident_id: incident.id, updated_at: Time.current)
        end

        # Return updated incident struct
        Success(@incident_repo.find(incident.id))
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end