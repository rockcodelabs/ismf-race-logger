# frozen_string_literal: true

module Operations
  module Notes
    # Creates a new note on a Report or Incident
    #
    # Returns:
    # - Success(Structs::Note) on success
    # - Failure(:validation_failed, errors) on invalid input
    # - Failure(:notable_not_found, message) if notable doesn't exist
    # - Failure(:error, message) on unexpected error
    #
    class Create
      include Dry::Monads[:result]

      def initialize(note_repo: NoteRepo.new)
        @note_repo = note_repo
        @contract = Operations::Contracts::CreateNote.new
      end

      def call(params)
        validation = @contract.call(params)
        return Failure([:validation_failed, validation.errors.to_h]) unless validation.success?

        validated = validation.to_h

        # Verify the notable exists
        notable_class = validated[:notable_type].constantize
        notable = notable_class.find_by(id: validated[:notable_id])
        return Failure([:notable_not_found, "#{validated[:notable_type]} ##{validated[:notable_id]} not found"]) unless notable

        # Create the note
        record = Note.create!(
          notable_type: validated[:notable_type],
          notable_id: validated[:notable_id],
          user_id: validated[:user_id],
          body: validated[:body].strip
        )

        Success(@note_repo.find(record.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([:validation_error, e.message])
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end