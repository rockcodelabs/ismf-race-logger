# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      module Races
        # Controller for managing race participations
        #
        # This controller handles CRUD operations for race participations,
        # allowing admins to add/remove athletes from races.
        #
        # Routes:
        #   DELETE /admin/competitions/:competition_id/races/:race_id/participations/:id
        #
        class ParticipationsController < Admin::BaseController
          before_action :set_competition
          before_action :set_race
          before_action :set_participation, only: [ :destroy ]

          # POST /admin/competitions/:competition_id/races/:race_id/participations/copy
          #
          # Copies participants from another race (same gender category)
          def copy
            authorize RaceParticipation

            source_race_id = params[:source_race_id]

            unless source_race_id.present?
              redirect_to admin_competition_race_path(@competition, @race),
                         alert: "Please select a source race to copy from."
              return
            end

            result = Operations::Athletes::CopyParticipants.new.call(
              target_race_id: @race.id,
              source_race_id: source_race_id
            )

            if result.success?
              summary = result.value!
              message = "✓ Copied #{summary[:copied_count]} participant#{'s' unless summary[:copied_count] == 1}"
              message += " (#{summary[:skipped_count]} skipped)" if summary[:skipped_count] > 0

              redirect_to admin_competition_race_path(@competition, @race),
                         notice: message
            else
              redirect_to admin_competition_race_path(@competition, @race),
                         alert: result.failure
            end
          end

          # DELETE /admin/competitions/:competition_id/races/:race_id/participations/:id
          #
          # Removes an athlete from the race
          def destroy
            authorize @participation

            if @participation.destroy
              respond_to do |format|
                format.turbo_stream do
                  render turbo_stream: turbo_stream.remove("participation_#{@participation.id}")
                end
                format.html do
                  redirect_to admin_competition_race_path(@competition, @race),
                             notice: "Athlete removed from race successfully."
                end
              end
            else
              respond_to do |format|
                format.turbo_stream do
                  render turbo_stream: turbo_stream.replace(
                    "participation_#{@participation.id}",
                    partial: "admin/races/participation_error",
                    locals: { participation: @participation }
                  )
                end
                format.html do
                  redirect_to admin_competition_race_path(@competition, @race),
                             alert: "Failed to remove athlete from race."
                end
              end
            end
          end

          # POST /admin/competitions/:competition_id/races/:race_id/participations/bulk_destroy
          #
          # Bulk delete participations - either selected or remove rest (inverse)
          def bulk_destroy
            authorize RaceParticipation

            participation_ids = params[:participation_ids]&.map(&:to_i)&.compact || []
            participation_ids_to_keep = params[:participation_ids_to_keep]&.map(&:to_i)&.compact || []

            if participation_ids.empty? && participation_ids_to_keep.empty?
              return respond_to do |format|
                format.turbo_stream do
                  render turbo_stream: turbo_stream.update("bulk-action-bar",
                    partial: "admin/races/bulk_action_bar",
                    locals: { race: @race, competition: @competition, message: "No participants selected" }
                  )
                end
                format.html do
                  redirect_to admin_competition_race_path(@competition, @race),
                             alert: "No participants selected."
                end
              end
            end

            result = Operations::RaceParticipations::BulkDelete.new.call(
              race_id: @race.id,
              participation_ids: participation_ids,
              participation_ids_to_keep: participation_ids_to_keep
            )

            case result
            in Dry::Monads::Success(deleted_count:)
              respond_to do |format|
                format.turbo_stream do
                  # Build stream with individual remove commands
                  ids_to_remove = participation_ids.presence || (
                    all_participations = race_participation_repo.for_race(@race.id)
                    all_ids = all_participations.map(&:id)
                    all_ids - participation_ids_to_keep
                  )

                  stream = ids_to_remove.map do |id|
                    turbo_stream.remove("participation_#{id}")
                  end

                  render turbo_stream: stream
                end
                format.html do
                  redirect_to admin_competition_race_path(@competition, @race),
                             notice: "Removed #{deleted_count} participant#{'s' unless deleted_count == 1}."
                end
              end
            in Dry::Monads::Failure(error)
              error_message = error.values.first
              respond_to do |format|
                format.turbo_stream do
                  render turbo_stream: turbo_stream.update("bulk-action-bar",
                    partial: "admin/races/bulk_action_bar",
                    locals: { race: @race, competition: @competition, message: "Error: #{error_message}" }
                  )
                end
                format.html do
                  redirect_to admin_competition_race_path(@competition, @race),
                             alert: "Failed to remove participants: #{error_message}"
                end
              end
            end
          end

          private

          def set_competition
            @competition = competition_repo.find(params[:competition_id])

            unless @competition
              redirect_to admin_competitions_path, alert: "Competition not found"
            end
          end

          def set_race
            @race = race_repo.find(params[:race_id])

            unless @race && @race.competition_id == @competition.id
              redirect_to admin_competition_races_path(@competition), alert: "Race not found"
            end
          end

          def set_participation
            @participation = RaceParticipation.find(params[:id])

            unless @participation.race_id == @race.id
              redirect_to admin_competition_race_path(@competition, @race),
                         alert: "Participation not found"
            end
          end

          def competition_repo
            @competition_repo ||= AppContainer["repos.competition"]
          end

          def race_repo
            @race_repo ||= AppContainer["repos.race"]
          end

          def race_participation_repo
            @race_participation_repo ||= AppContainer["repos.race_participation"]
          end
        end
      end
    end
  end
end
