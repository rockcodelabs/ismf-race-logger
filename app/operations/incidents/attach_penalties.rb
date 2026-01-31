# frozen_string_literal: true

module Operations
  module Incidents
    # AttachPenalties Operation
    #
    # Attaches penalties to an incident.
    # Replaces any existing penalties with the new set.
    #
    # This operation:
    # 1. Validates the input parameters via contract
    # 2. Removes existing penalty attachments
    # 3. Creates new penalty attachments
    # 4. Returns the updated incident struct
    #
    # Returns:
    # - Success(Structs::Incident) if penalties attached
    # - Failure(:validation_failed, errors) if validation fails
    # - Failure(:not_found) if incident doesn't exist
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Incidents::AttachPenalties.new.call(
    #     incident_id: 1,
    #     penalty_ids: [5, 12, 23]
    #   )
    #
    #   result.success?               # => true
    #   result.value!.penalties_count # => 3
    #
    class AttachPenalties
      include Dry::Monads[:result]

      def initialize(incident_repo: IncidentRepo.new)
        @incident_repo = incident_repo
        @contract = Operations::Contracts::AttachPenalties.new
      end

      def call(params)
        # Validate input via contract
        validation = @contract.call(params)
        return Failure([ :validation_failed, validation.errors.to_h ]) unless validation.success?

        validated = validation.to_h
        incident_id = validated[:incident_id]
        penalty_ids = validated[:penalty_ids].uniq

        # Find the incident
        incident = Incident.find_by(id: incident_id)
        return Failure(:not_found) unless incident

        # Replace penalties in a transaction
        ActiveRecord::Base.transaction do
          # Remove existing penalty attachments
          incident.incident_penalties.destroy_all

          # Create new penalty attachments
          penalty_ids.each do |penalty_id|
            IncidentPenalty.create!(
              incident_id: incident_id,
              penalty_id: penalty_id
            )
          end
        end

        # Return updated struct from repo
        Success(@incident_repo.find(incident_id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([ :validation_error, e.message ])
      rescue StandardError => e
        Failure([ :error, e.message ])
      end
    end
  end
end
