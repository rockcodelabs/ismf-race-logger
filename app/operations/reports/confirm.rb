# frozen_string_literal: true

module Operations
  module Reports
    # Confirm Operation
    #
    # Confirms a report that is pending review.
    # Confirmed reports can then be merged into incidents.
    #
    # This operation:
    # 1. Validates the report exists and is pending_review
    # 2. Updates the status to 'confirmed'
    # 3. Returns a struct (not the AR model)
    #
    # Returns:
    # - Success(Structs::Report) if report confirmed
    # - Failure(:not_found, message) if report doesn't exist
    # - Failure(:invalid_status, message) if report is not pending_review
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Reports::Confirm.new.call(id: 1)
    #
    #   result.success?        # => true
    #   result.value!.status   # => "confirmed"
    #
    class Confirm
      include Dry::Monads[:result]

      def initialize(report_repo: ReportRepo.new)
        @report_repo = report_repo
      end

      def call(id:)
        # Find the report
        report = Report.find_by(id: id)
        return Failure([ :not_found, "Report with ID #{id} not found" ]) unless report

        # Validate status
        unless report.status == "pending_review"
          return Failure([ :invalid_status, "Report must be pending_review to confirm (current: #{report.status})" ])
        end

        # Update status
        report.update!(status: "confirmed")

        # Return struct from repo
        Success(@report_repo.find(report.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([ :validation_error, e.message ])
      rescue StandardError => e
        Failure([ :error, e.message ])
      end
    end
  end
end
