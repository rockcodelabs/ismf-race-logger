# frozen_string_literal: true

module Operations
  module Reports
    # Create Operation
    #
    # Creates a report during a live race.
    # Reports are quick captures of potential incidents (location + bib).
    #
    # This operation:
    # 1. Validates the input parameters via contract
    # 2. Checks for idempotency via client_uuid
    # 3. Creates the report record with status 'pending_review'
    # 4. Returns a struct (not the AR model)
    #
    # Returns:
    # - Success(Structs::Report) if report created
    # - Success(Structs::Report) if report already exists (idempotent via client_uuid)
    # - Failure(:validation_failed, errors) if validation fails
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Reports::Create.new.call(
    #     race_id: 1,
    #     race_location_id: 5,
    #     race_participation_id: 12,
    #     bib_number: 42,
    #     user_id: 1,
    #     athlete_position: nil,
    #     description: nil,
    #     client_uuid: "550e8400-e29b-41d4-a716-446655440000"
    #   )
    #
    #   result.success?           # => true
    #   result.value!.bib_number  # => 42
    #
    class Create
      include Dry::Monads[:result]

      def initialize(report_repo: ReportRepo.new)
        @report_repo = report_repo
        @contract = Operations::Contracts::CreateReport.new
      end

      def call(params)
        # Validate input via contract
        validation = @contract.call(params)
        return Failure([ :validation_failed, validation.errors.to_h ]) unless validation.success?

        validated = validation.to_h

        # Check for idempotency via client_uuid
        if validated[:client_uuid].present?
          existing = @report_repo.find_by_client_uuid(validated[:client_uuid])
          return Success(existing) if existing
        end

        # Create the report
        report = Report.create!(
          client_uuid: validated[:client_uuid] || SecureRandom.uuid,
          race_id: validated[:race_id],
          race_location_id: validated[:race_location_id],
          race_participation_id: validated[:race_participation_id],
          bib_number: validated[:bib_number],
          user_id: validated[:user_id],
          athlete_position: validated[:athlete_position],
          description: validated[:description],
          status: "pending_review"
        )

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
