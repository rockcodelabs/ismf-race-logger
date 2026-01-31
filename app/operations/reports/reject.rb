# frozen_string_literal: true

module Operations
  module Reports
    # Reject Operation
    #
    # Rejects a pending report (marks it as rejected).
    # Rejected reports will not be merged into incidents.
    #
    # This operation:
    # 1. Validates the report exists and is pending_review
    # 2. Updates the status to 'rejected'
    # 3. Returns the updated struct
    #
    # Returns:
    # - Success(Structs::Report) if report rejected
    # - Failure(:not_found) if report doesn't exist
    # - Failure(:invalid_status) if report is not pending_review
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Reports::Reject.new.call(id: 123)
    #
    #   result.success?        # => true
    #   result.value!.status   # => "rejected"
    #
    class Reject
      include Dry::Monads[:result]

      def initialize(report_repo: ReportRepo.new)
        @report_repo = report_repo
      end

      def call(id:)
        # Find the report
        report = Report.find_by(id: id)
        return Failure(:not_found) unless report

        # Validate status
        unless report.status == "pending_review"
          return Failure([ :invalid_status, "Report must be pending_review to reject (current status: #{report.status})" ])
        end

        # Update the status
        report.update!(status: "rejected")

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
