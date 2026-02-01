# frozen_string_literal: true

module Operations
  module Reports
    # UpdateBib Operation
    #
    # Updates the bib number and race participation for an existing report.
    # Used when a report is created with "Number NN" (unknown bib) and later
    # needs to be assigned to a specific athlete.
    #
    # This operation:
    # 1. Validates the input parameters
    # 2. Updates the report's bib_number and race_participation_id
    # 3. Returns the updated struct
    #
    # Returns:
    # - Success(Structs::Report) if report updated successfully
    # - Failure(:not_found, message) if report not found
    # - Failure(:validation_failed, errors) if validation fails
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Reports::UpdateBib.new.call(
    #     report_id: 1,
    #     race_participation_id: 12,
    #     bib_number: 42
    #   )
    #
    #   result.success?           # => true
    #   result.value!.bib_number  # => 42
    #
    class UpdateBib
      include Dry::Monads[:result]

      def initialize(report_repo: ReportRepo.new)
        @report_repo = report_repo
        @contract = Operations::Contracts::UpdateReportBib.new
      end

      def call(params)
        # Validate input via contract
        validation = @contract.call(params)
        return Failure([:validation_failed, validation.errors.to_h]) unless validation.success?

        validated = validation.to_h

        # Find the report
        report_record = Report.find_by(id: validated[:report_id])
        return Failure([:not_found, "Report with ID #{validated[:report_id]} not found"]) unless report_record

        # Update the report
        report_record.update!(
          race_participation_id: validated[:race_participation_id],
          bib_number: validated[:bib_number]
        )

        # Return updated struct from repo
        Success(@report_repo.find(report_record.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([:validation_error, e.message])
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end