# frozen_string_literal: true

module Operations
  module Reports
    # Confirm Operation
    #
    # Confirms a report that is pending review and automatically creates an Incident.
    # This is the unified entry point — confirming a report IS creating an incident.
    #
    # This operation:
    # 1. Validates the report exists and is pending_review
    # 2. Delegates to Operations::Incidents::Create which:
    #    - Creates the Incident record (status: pending)
    #    - Sets report.status = "confirmed"
    #    - Sets report.incident_id = incident.id
    # 3. Returns the updated Structs::Report
    #
    # Returns:
    # - Success(Structs::Report) if report confirmed and incident created
    # - Failure(:not_found, message) if report doesn't exist
    # - Failure(:invalid_status, message) if report is not pending_review
    # - Failure([:validation_failed, errors]) if incident creation validation fails
    # - Failure([:error, message]) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Reports::Confirm.new.call(id: 1)
    #
    #   result.success?                  # => true
    #   result.value!.status             # => "confirmed"
    #   result.value!.incident_id        # => 42 (auto-created incident)
    #
    class Confirm
      include Dry::Monads[:result]

      def initialize(report_repo: ReportRepo.new, incident_create: nil)
        @report_repo = report_repo
        # Allow injection for testing; lazily instantiated to avoid circular load issues
        @incident_create = incident_create
      end

      def call(id:)
        # Find the report
        report = Report.find_by(id: id)
        return Failure([ :not_found, "Report with ID #{id} not found" ]) unless report

        # Validate status — fast fail before delegating
        unless report.status == "pending_review"
          return Failure([ :invalid_status, "Report must be pending_review to confirm (current: #{report.status})" ])
        end

        # Create the incident, which also confirms the report and sets incident_id
        result = incident_create_operation.call(report_ids: [ id ])
        return Failure(result.failure) if result.failure?

        # Return the updated report struct (now has status: "confirmed" + incident_id)
        Success(@report_repo.find(id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([ :validation_error, e.message ])
      rescue StandardError => e
        Failure([ :error, e.message ])
      end

      private

      def incident_create_operation
        @incident_create ||= Operations::Incidents::Create.new
      end
    end
  end
end