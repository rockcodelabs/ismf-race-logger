# frozen_string_literal: true

module Operations
  module Notes
    # Deletes a note
    #
    # Returns:
    # - Success(true) on success
    # - Failure(:not_found, message) if note doesn't exist
    # - Failure(:error, message) on unexpected error
    #
    class Delete
      include Dry::Monads[:result]

      def call(note_id:)
        record = Note.find_by(id: note_id)
        return Failure([:not_found, "Note ##{note_id} not found"]) unless record

        record.destroy!

        Success(true)
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end