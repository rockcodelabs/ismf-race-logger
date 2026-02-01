# frozen_string_literal: true

module Operations
  module Incidents
    # Merge Operation
    #
    # Merges two incidents into one by moving all reports from the source incident
    # to the target incident, then deleting the source incident.
    #
    # This operation:
    # 1. Validates both incidents exist
    # 2. Validates both incidents belong to the same race
    # 3. Moves all reports from source incident to target incident
    # 4. Optionally merges descriptions
    # 5. Deletes the source incident
    # 6. Returns the updated target incident struct
    #
    # Returns:
    # - Success(Structs::Incident) if merge successful
    # - Failure(:source_not_found) if source incident doesn't exist
    # - Failure(:target_not_found) if target incident doesn't exist
    # - Failure(:different_races) if incidents belong to different races
    # - Failure(:cannot_merge_self) if trying to merge incident with itself
    # - Failure(:error, message) if unexpected error occurs
    #
    # Example:
    #   result = Operations::Incidents::Merge.new.call(
    #     source_incident_id: 10,
    #     target_incident_id: 5,
    #     merge_descriptions: true
    #   )
    #
    #   result.success?                # => true
    #   result.value!.reports_count    # => 8 (combined from both incidents)
    #
    class Merge
      include Dry::Monads[:result]

      def initialize(incident_repo: IncidentRepo.new)
        @incident_repo = incident_repo
      end

      def call(source_incident_id:, target_incident_id:, merge_descriptions: false)
        # Validate not merging with self
        if source_incident_id == target_incident_id
          return Failure([:cannot_merge_self, "Cannot merge an incident with itself"])
        end

        # Find both incidents
        source = Incident.includes(:reports).find_by(id: source_incident_id)
        return Failure(:source_not_found) unless source

        target = Incident.includes(:reports).find_by(id: target_incident_id)
        return Failure(:target_not_found) unless target

        # Validate same race
        if source.race_id != target.race_id
          return Failure([:different_races, "Cannot merge incidents from different races"])
        end

        # Perform merge in transaction
        ActiveRecord::Base.transaction do
          # Move all reports from source to target
          source.reports.update_all(
            incident_id: target.id,
            updated_at: Time.current
          )

          # Optionally merge descriptions
          if merge_descriptions && source.description.present?
            merged_description = if target.description.present?
              "#{target.description}\n\n---\n\n#{source.description}"
            else
              source.description
            end
            target.update!(description: merged_description)
          end

          # Delete the source incident (reports are already moved)
          source.destroy!
        end

        # Return updated target incident struct
        Success(@incident_repo.find(target.id))
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end