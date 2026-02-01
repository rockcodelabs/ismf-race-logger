# frozen_string_literal: true

module Operations
  module Races
    # Operation: Cancel a race
    #
    # Marks a race as cancelled. Only scheduled or in_progress races can be cancelled.
    #
    # Usage:
    #   result = Operations::Races::Cancel.new.call(id: 123)
    #
    # Success:
    #   Success(Structs::Race) - Returns updated race struct
    #
    # Failure:
    #   [:not_found, "Race not found"]
    #   [:invalid_status, "Race is already completed and cannot be cancelled"]
    #   [:database_error, String]
    #
    class Cancel
      include Dry::Monads[:result]

      def call(id:)
        race = Race.find_by(id: id)
        return Failure([:not_found, "Race not found"]) unless race

        # Validate race can be cancelled
        if race.status == "completed"
          return Failure([:invalid_status, "Race is already completed and cannot be cancelled"])
        end

        # Update race status
        race.update!(status: "cancelled")

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