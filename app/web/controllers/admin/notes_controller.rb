# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # NotesController - CRUD for polymorphic notes
      #
      # Notes can be attached to Reports or Incidents.
      # Uses Turbo Frames for inline editing without page reload.
      #
      class NotesController < Admin::BaseController
        include Dry::Monads[:result]

        before_action :set_note, only: [:edit, :update, :destroy]

        def create
          authorize Note, :create?

          result = Operations::Notes::Create.new.call(
            notable_type: params[:notable_type],
            notable_id: params[:notable_id].to_i,
            user_id: Current.user.id,
            body: params[:body]
          )

          case result
          in Success(note)
            redirect_back fallback_location: root_path, notice: "Note added."
          in Failure([:validation_failed, errors])
            redirect_back fallback_location: root_path, alert: "Could not add note: #{errors.values.flatten.join(', ')}"
          in Failure([:notable_not_found, message])
            redirect_back fallback_location: root_path, alert: message
          in Failure
            redirect_back fallback_location: root_path, alert: "Could not add note."
          end
        end

        def edit
          authorize @note_record, :update?
          @note = note_repo.find(@note_record.id)
        end

        def update
          authorize @note_record, :update?

          result = Operations::Notes::Update.new.call(
            note_id: @note_record.id,
            body: params[:body]
          )

          case result
          in Success(note)
            redirect_back fallback_location: root_path, notice: "Note updated."
          in Failure([:validation_failed, errors])
            redirect_back fallback_location: root_path, alert: "Could not update note: #{errors.values.flatten.join(', ')}"
          in Failure
            redirect_back fallback_location: root_path, alert: "Could not update note."
          end
        end

        def destroy
          authorize @note_record, :update?

          result = Operations::Notes::Delete.new.call(note_id: @note_record.id)

          case result
          in Success
            redirect_back fallback_location: root_path, notice: "Note deleted."
          in Failure
            redirect_back fallback_location: root_path, alert: "Could not delete note."
          end
        end

        private

        def set_note
          @note_record = Note.find(params[:id])
        end

        def note_repo
          @note_repo ||= AppContainer["repos.note"]
        end
      end
    end
  end
end