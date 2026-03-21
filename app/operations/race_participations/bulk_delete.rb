# frozen_string_literal: true

require "dry/monads"

module Operations
  module RaceParticipations
    # Operation for bulk deleting race participations
    #
    # Supports two modes:
    # 1. Delete selected participants by ID
    # 2. Delete all except selected participants (remove rest)
    #
    # Example:
    #   # Delete specific participants
    #   result = Operations::RaceParticipations::BulkDelete.new.call(
    #     race_id: 50,
    #     participation_ids: [1, 2, 3]
    #   )
    #
    #   # Delete all except selected (remove rest)
    #   result = Operations::RaceParticipations::BulkDelete.new.call(
    #     race_id: 50,
    #     participation_ids_to_keep: [4, 5]
    #   )
    #
    class BulkDelete
      include Dry::Monads[:result]
      include Import[
        participation_repo: "repos.race_participation"
      ]

      # @param race_id [Integer] Race ID
      # @param participation_ids [Array<Integer>] IDs to delete (optional)
      # @param participation_ids_to_keep [Array<Integer>] IDs to keep (optional)
      # @return [Dry::Monads::Result] Success({deleted_count: N}) or Failure(error)
      def call(race_id:, participation_ids: nil, participation_ids_to_keep: nil)
        # Determine which IDs to delete
        ids_to_delete = determine_ids_to_delete(race_id, participation_ids, participation_ids_to_keep)

        if ids_to_delete.empty?
          return Failure(empty: "No participations to delete")
        end

        deleted_count = 0
        errors = []

        ids_to_delete.each do |participation_id|
          begin
            RaceParticipation.destroy(participation_id)
            deleted_count += 1
          rescue StandardError => e
            errors << "ID #{participation_id}: #{e.message}"
          end
        end

        if deleted_count > 0
          Success(deleted_count: deleted_count, errors: errors)
        else
          Failure(deletion_failed: "Failed to delete any participations: #{errors.join(', ')}")
        end
      end

      private

      # Determine which participation IDs should be deleted
      #
      # @param race_id [Integer]
      # @param participation_ids [Array<Integer>] IDs to delete
      # @param participation_ids_to_keep [Array<Integer>] IDs to keep
      # @return [Array<Integer>]
      def determine_ids_to_delete(race_id, participation_ids, participation_ids_to_keep)
        if participation_ids.present?
          # Delete specific participants
          participation_ids
        elsif participation_ids_to_keep.present?
          # Delete all except the ones to keep
          all_participations = participation_repo.for_race(race_id)
          all_ids = all_participations.map(&:id)
          all_ids - participation_ids_to_keep
        else
          []
        end
      end
    end
  end
end