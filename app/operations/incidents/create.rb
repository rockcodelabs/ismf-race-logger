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
    # 2. Ensures all reports exist and belong to same race
    # 3. Moves reports from existing incidents if needed (unlinks them first)
    # 4. Creates the incident record with status 'pending'
    # 5. Links all reports to the new incident
    # 6. Returns a struct (not the AR model)
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

        # Ensure report_ids is present and is an array
        report_ids = Array(validated[:report_ids])
        return Failure([ :no_reports_provided, "No report IDs provided" ]) if report_ids.empty?

        # Load the reports
        reports = Report.where(id: report_ids).order(:created_at)
        
        # Validate all reports were found
        found_ids = reports.pluck(:id)
        missing_ids = report_ids - found_ids
        return Failure([ :reports_not_found, missing_ids ]) if missing_ids.any?

        # Note: We now ALLOW reports that are already linked to incidents
        # They will be moved to the new incident (unlinked from old, linked to new)
        # The UI handles confirmation for reports in incidents with decisions

        first_report = reports.first

        # Determine race_location_id (from params or first report)
        race_location_id = validated[:race_location_id] || first_report.race_location_id

        # Create the incident within a transaction
        incident = nil
        old_incident_ids = reports.where.not(incident_id: nil).pluck(:incident_id).uniq
        
        ActiveRecord::Base.transaction do
          incident = Incident.create!(
            client_uuid: SecureRandom.uuid,
            race_id: first_report.race_id,
            race_location_id: race_location_id,
            status: "pending",
            description: validated[:description]
          )

          # Move reports to this incident (unlinks from old, links to new)
          # This works for both new reports (incident_id was nil) and existing reports
          reports.update_all(
            incident_id: incident.id,
            status: "confirmed",
            updated_at: Time.current
          )
          
          # Clean up old incidents that now have no reports
          old_incident_ids.each do |old_incident_id|
            old_incident = Incident.find_by(id: old_incident_id)
            if old_incident && old_incident.reports.count == 0
              old_incident.destroy
            end
          end
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
