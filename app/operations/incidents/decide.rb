# frozen_string_literal: true

module Operations
  module Incidents
    # Decide Operation
    #
    # Makes a decision on an incident (approve or reject).
    # This is the final step in the incident workflow.
    #
    # This operation:
    # 1. Validates the input parameters via contract
    # 2. Ensures the incident is pending
    # 3. Updates the incident status (approved/rejected)
    # 4. Records who made the decision and when
    # 5. Optionally attaches penalties
    # 6. When approving, confirms all associated pending reports
    # 7. When rejecting, rejects all associated pending reports
    # 8. Returns the updated struct
    #
    # Returns:
    # - Success(Structs::Incident) if incident decided
    # - Failure(:validation_failed, errors) if validation fails
    # - Failure(:not_found) if incident doesn't exist
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Incidents::Decide.new.call(
    #     id: 1,
    #     status: "approved",
    #     user_id: 5,
    #     description: "Clear violation observed",
    #     penalty_ids: [3, 7]
    #   )
    #
    #   result.success?           # => true
    #   result.value!.status      # => "approved"
    #   result.value!.decided?    # => true
    #
    class Decide
      include Dry::Monads[:result]

      def initialize(incident_repo: IncidentRepo.new)
        @incident_repo = incident_repo
        @contract = Operations::Contracts::DecideIncident.new
      end

      def call(params)
        # Validate input via contract
        validation = @contract.call(params)
        return Failure([ :validation_failed, validation.errors.to_h ]) unless validation.success?

        validated = validation.to_h

        # Find the incident
        incident = Incident.find_by(id: validated[:id])
        return Failure(:not_found) unless incident

        # Update incident within a transaction
        ActiveRecord::Base.transaction do
          # Update the incident status and decision info
          incident.update!(
            status: validated[:status],
            description: validated[:description] || incident.description,
            decided_by_user_id: validated[:user_id],
            decided_at: Time.current
          )

          # Attach penalties if provided
          if validated[:penalty_ids].present?
            # Clear existing penalties and add new ones
            incident.incident_penalties.destroy_all

            validated[:penalty_ids].uniq.each do |penalty_id|
              IncidentPenalty.create!(
                incident_id: incident.id,
                penalty_id: penalty_id
              )
            end
          end

          # Update associated reports based on decision
          if validated[:status] == "approved"
            # When approving, confirm all associated pending reports
            Report.where(incident_id: incident.id, status: "pending_review").update_all(status: "confirmed")
          elsif validated[:status] == "rejected"
            # When rejecting, reject all associated reports (pending_review AND confirmed)
            Report.where(incident_id: incident.id, status: %w[pending_review confirmed]).update_all(status: "rejected")
          end
        end

        # Return updated struct from repo
        Success(@incident_repo.find(incident.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([ :validation_error, e.message ])
      rescue StandardError => e
        Failure([ :error, e.message ])
      end
    end
  end
end
