# frozen_string_literal: true

module Operations
  module Races
    # Operation: Complete a race
    #
    # Marks a race as completed. Only races that are in_progress can be completed.
    #
    # Usage:
    #   result = Operations::Races::Complete.new.call(id: 123)
    #
    # Success:
    #   Success(Structs::Race) - Returns updated race struct
    #
    # Failure:
    #   [:not_found, "Race not found"]
    #   [:invalid_status, "Race must be in progress to complete"]
    #   [:database_error, String]
    #
    class Complete
      include Dry::Monads[:result]

      def call(id:)
        race = Race.find_by(id: id)
        return Failure([:not_found, "Race not found"]) unless race

        # Validate race can be completed
        return Failure([:invalid_status, "Race must be in progress to complete"]) unless race.status == "in_progress"

        # Update race status
        race.update!(status: "completed")

        # Return struct for consistency
        race_repo = AppContainer["repos.race"]
        Success(race_repo.find!(id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([:validation_failed, e.record.errors.full_messages])
      rescue ActiveRecord::RecordNotFound
        Failure([:not_found, "Race not found"])
      rescue StandardError => e
        Failure([:database_error, e.message])
      end

      private

      def race_repo
        @race_repo ||= AppContainer["repos.race"]
      end
    end
  end
end