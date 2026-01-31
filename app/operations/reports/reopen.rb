# frozen_string_literal: true

module Operations
  module Reports
    # Reopen Operation
    #
    # Reopens a confirmed or rejected report, returning it to pending_review status.
    # Used when a report needs to be reconsidered.
    #
    # This operation:
    # 1. Validates the report exists
    # 2. Validates the report is not already pending_review
    # 3. Unlinks from incident if linked
    # 4. Updates status to pending_review
    # 5. Returns the updated struct
    #
    # Returns:
    # - Success(Structs::Report) if report reopened
    # - Failure(:not_found) if report doesn't exist
    # - Failure(:already_pending) if report is already pending_review
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Reports::Reopen.new.call(id: 123)
    #
    #   result.success?         # => true
    #   result.value!.status    # => "pending_review"
    #
    class Reopen
      include Dry::Monads[:result]

      def initialize(report_repo: ReportRepo.new)
        @report_repo = report_repo
      end

      def call(id:)
        # Find the report
        report = Report.find_by(id: id)
        return Failure(:not_found) unless report

        # Validate report is not already pending
        if report.status == "pending_review"
          return Failure(:already_pending)
        end

        # Unlink from incident if linked
        # (reopening a report removes it from the incident)
        was_linked = report.incident_id.present?

        # Update the report
        report.update!(
          status: "pending_review",
          incident_id: nil
        )

        # Return updated struct
        Success(@report_repo.find(report.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([ :validation_error, e.message ])
      rescue StandardError => e
        Failure([ :error, e.message ])
      end
    end
  end
end
