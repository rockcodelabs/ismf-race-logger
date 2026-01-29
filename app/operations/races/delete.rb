# frozen_string_literal: true

module Operations
  module Races
    # Delete a race
    #
    # This operation:
    # - Finds the race
    # - Deletes it (no restrictions for now, admins/VAR can delete anytime)
    #
    # Note: In the future, we might want to add soft-delete or restrictions
    # based on whether the race has participants, reports, etc.
    #
    # @example
    #   result = Operations::Races::Delete.new.call(id: 1)
    #
    #   case result
    #   in Success(true)
    #     # race deleted successfully
    #   in Failure(errors)
    #     # errors is a hash with failure reason
    #   end
    #
    class Delete
      include Dry::Monads[:result]
      include Import[
        race_repo: "repos.race"
      ]

      # @param id [Integer] Race ID
      # @return [Dry::Monads::Result] Success(true) or Failure(errors)
      def call(id:)
        # Find existing race
        existing_race = race_repo.find(id)
        return Failure(not_found: "Race not found") unless existing_race

        # Delete the race via injected repo
        race_repo.delete(id)

        Success(true)
      rescue ActiveRecord::RecordNotFound
        Failure(not_found: "Race not found")
      rescue ActiveRecord::InvalidForeignKey => e
        Failure(foreign_key: "Cannot delete race: #{e.message}")
      rescue StandardError => e
        Failure(unexpected: e.message)
      end
    end
  end
end