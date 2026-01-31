# frozen_string_literal: true

module Operations
  module Incidents
    # Create Operation
    #
    # Creates an incident by merging one or more confirmed reports.
    # This is the main workflow step where reports become actionable incidents.
    #
    # This operation:
    # 1. Validates the input parameters via contract
    # 2. Ensures all reports are confirmed and not yet linked
    # 3. Creates the incident record with status 'pending'
    # 4. Links all reports to the incident
    # 5. Returns a struct (not the AR model)
    #
    # Returns:
    # - Success(Structs::Incident) if incident created
    # - Failure(:validation_failed, errors) if validation fails
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Incidents::Create.new.call(
    #     report_ids: [1, 2, 3],
    #     description: "Multiple reports of same infraction"
    #   )
    #
    #   result.success?              # => true
    #   result.value!.reports_count  # => 3
    #
    class Create
      include Dry::Monads[:result]

      def initialize(incident_repo: IncidentRepo.new)
        @incident_repo = incident_repo
        @contract = Operations::Contracts::CreateIncident.new
      end

      def call(params)
        # Validate input via contract
        validation = @contract.call(params)
        return Failure([ :validation_failed, validation.errors.to_h ]) unless validation.success?

        validated = validation.to_h

        # Load the reports
        reports = Report.where(id: validated[:report_ids]).order(:created_at)
        first_report = reports.first

        # Determine race_location_id (from params or first report)
        race_location_id = validated[:race_location_id] || first_report.race_location_id

        # Create the incident within a transaction
        incident = nil
        ActiveRecord::Base.transaction do
          incident = Incident.create!(
            client_uuid: SecureRandom.uuid,
            race_id: first_report.race_id,
            race_location_id: race_location_id,
            status: "pending",
            description: validated[:description]
          )

          # Link all reports to this incident
          reports.update_all(incident_id: incident.id)
        end

        # Return struct from repo
        Success(@incident_repo.find(incident.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([ :validation_error, e.message ])
      rescue StandardError => e
        Failure([ :error, e.message ])
      end
    end
  end
end
