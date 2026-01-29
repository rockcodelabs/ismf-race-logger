# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      module Races
        # Controller for importing athletes into races via JSON
        #
        # This controller provides UI for bulk importing athletes into a race.
        # Admins can paste JSON data and see import results or errors.
        #
        # Routes:
        #   GET  /admin/races/:race_id/import_athletes - Show import form
        #   POST /admin/races/:race_id/import_athletes - Process import
        #
        class ImportsController < Admin::BaseController
          before_action :set_race

          # GET /admin/races/:race_id/import_athletes
          #
          # Shows the import form with a textarea for pasting JSON
          def new
            render :new
          end

          # POST /admin/races/:race_id/import_athletes
          #
          # Processes the JSON import and redirects to race show page on success
          def create
            result = import_operation.call(
              race_id: @race.id,
              athletes_json: params[:athletes_json]
            )

            if result.success?
              summary = result.value!
              flash[:notice] = "✓ #{summary.summary_message}"
              redirect_to admin_competition_race_path(@competition, @race)
            else
              handle_import_errors(result.failure)
            end
          end

          private

          def set_race
            @race = race_repo.find(params[:race_id])
            
            unless @race
              redirect_to admin_races_path, alert: "Race not found"
              return
            end
            
            @competition = competition_repo.find(@race.competition_id)
          end

          def handle_import_errors(failure)
            if failure.is_a?(Hash)
              if failure[:errors]
                # Array of error messages
                flash.now[:alert] = build_error_message(failure[:errors])
              else
                # Validation errors from contract
                flash.now[:alert] = build_validation_errors(failure)
              end
            else
              # String error (e.g., JSON parse error)
              flash.now[:alert] = failure
            end
            
            render :new, status: :unprocessable_entity
          end

          def build_error_message(errors)
            header = errors.size == 1 ? "1 error occurred:" : "#{errors.size} errors occurred:"
            message = "<strong>#{header}</strong><br>"
            message += errors.map { |err| "• #{err}" }.join("<br>")
            message.html_safe
          end

          def build_validation_errors(errors_hash)
            messages = []
            errors_hash.each do |field, field_errors|
              Array(field_errors).each do |error|
                messages << "#{field}: #{error}"
              end
            end
            build_error_message(messages)
          end

          def import_operation
            Operations::Athletes::BulkImport.new
          end

          def race_repo
            @race_repo ||= AppContainer["repos.race"]
          end

          def competition_repo
            @competition_repo ||= AppContainer["repos.competition"]
          end
        end
      end
    end
  end
end