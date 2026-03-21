# frozen_string_literal: true

module Operations
  module Notes
    # Updates an existing note
    #
    # Returns:
    # - Success(Structs::Note) on success
    # - Failure(:validation_failed, errors) on invalid input
    # - Failure(:not_found, message) if note doesn't exist
    # - Failure(:error, message) on unexpected error
    #
    class Update
      include Dry::Monads[:result]

      def initialize(note_repo: NoteRepo.new)
        @note_repo = note_repo
        @contract = Operations::Contracts::UpdateNote.new
      end

      def call(params)
        validation = @contract.call(params)
        return Failure([:validation_failed, validation.errors.to_h]) unless validation.success?

        validated = validation.to_h

        record = Note.find_by(id: validated[:note_id])
        return Failure([:not_found, "Note ##{validated[:note_id]} not found"]) unless record

        record.update!(body: validated[:body].strip)

        Success(@note_repo.find(record.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([:validation_error, e.message])
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end