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
    # 3. Creates the report record
    # 4. If user is VAR operator → auto-creates incident (unofficial)
    # 5. If user is not VAR → report stays pending_review (VAR will organize later)
    # 6. Returns a struct (not the AR model)
    #
    # Returns:
    # - Success(Structs::Report) if report created (and incident if VAR)
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

      def initialize(report_repo: ReportRepo.new, user_repo: UserRepo.new, incident_repo: IncidentRepo.new)
        @report_repo = report_repo
        @user_repo = user_repo
        @incident_repo = incident_repo
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

        # Ensure bib_number and race_participation_id are nil if not provided
        validated[:bib_number] = nil unless validated[:bib_number].present?
        validated[:race_participation_id] = nil unless validated[:race_participation_id].present?

        # Load user to check role
        user = @user_repo.find(validated[:user_id])
        return Failure([ :user_not_found, "User with ID #{validated[:user_id]} not found" ]) unless user

        # Determine if we should auto-create incident (VAR operator only)
        auto_create_incident = user.var_operator?

        # Create report and optionally incident in transaction
        report = nil
        incident = nil

        ActiveRecord::Base.transaction do
          # Create the report (bib_number and race_participation_id can be nil)
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

          # Auto-create incident if VAR operator
          if auto_create_incident
            incident = Incident.create!(
              client_uuid: SecureRandom.uuid,
              race_id: report.race_id,
              race_location_id: report.race_location_id,
              status: "pending",
              description: validated[:description]
            )

            # Link report to incident
            report.update!(incident_id: incident.id)
          end
        end

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
