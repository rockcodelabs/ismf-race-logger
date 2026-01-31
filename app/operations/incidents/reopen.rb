# frozen_string_literal: true

module Operations
  module Incidents
    # Reopen Operation
    #
    # Reopens a decided incident, returning it to pending status.
    # Used when a decision needs to be reconsidered.
    #
    # This operation:
    # 1. Validates the incident exists
    # 2. Validates the incident is not already pending
    # 3. Clears the decision information
    # 4. Updates status to pending
    # 5. Returns the updated struct
    #
    # Returns:
    # - Success(Structs::Incident) if incident reopened
    # - Failure(:not_found) if incident doesn't exist
    # - Failure(:already_pending) if incident is already pending
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Incidents::Reopen.new.call(id: 123)
    #
    #   result.success?         # => true
    #   result.value!.status    # => "pending"
    #
    class Reopen
      include Dry::Monads[:result]

      def initialize(incident_repo: IncidentRepo.new)
        @incident_repo = incident_repo
      end

      def call(id:)
        # Find the incident
        incident = Incident.find_by(id: id)
        return Failure(:not_found) unless incident

        # Validate incident is not already pending
        if incident.status == "pending"
          return Failure(:already_pending)
        end

        # Update the incident (clear decision info, set back to pending)
        incident.update!(
          status: "pending",
          decided_by_user_id: nil,
          decided_at: nil
        )

        # Return updated struct
        Success(@incident_repo.find(incident.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([ :validation_error, e.message ])
      rescue StandardError => e
        Failure([ :error, e.message ])
      end
    end
  end
end
