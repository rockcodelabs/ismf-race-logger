# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      module Races
        # ReportsController - Admin CRUD for reports within a race
        #
        # Reports are quick captures of potential incidents during races.
        # This controller handles:
        # - Listing all reports for a race
        # - Viewing individual report details
        # - Creating new reports (desktop version)
        # - Confirming/Rejecting reports
        # - Reopening reports
        #
        # Pattern:
        # - Index: Use repo → summary structs (for lists)
        # - Show: Use repo → full struct (for detail)
        # - Create/Update: Use operations (business logic)
        #
        class ReportsController < Admin::BaseController
          before_action :set_race
          before_action :set_report, only: [ :show, :confirm, :reject, :reopen ]

          def index
            @reports = report_repo.for_race(@race.id)
            @reports = parts_factory.wrap_many(@reports)
            @status_counts = report_repo.count_by_status(@race.id)
          end

          def show
            @report = parts_factory.wrap(@report)
          end

          def new
            @race_locations = race_location_repo.for_race(@race.id)
            @participations = race_participation_repo.for_race(@race.id)
          end

          def create
            result = Operations::Reports::Create.new.call(
              race_id: @race.id,
              race_location_id: report_params[:race_location_id].to_i,
              race_participation_id: report_params[:race_participation_id].to_i,
              bib_number: report_params[:bib_number].to_i,
              user_id: Current.user.id,
              athlete_position: report_params[:athlete_position]&.to_i,
              description: report_params[:description]
            )

            case result
            in Success(report)
              redirect_to admin_race_report_path(@race, report),
                          notice: "Report created successfully."
            in Failure([ :validation_failed, errors ])
              flash.now[:alert] = "Validation failed: #{errors.values.flatten.join(', ')}"
              @race_locations = race_location_repo.for_race(@race.id)
              @participations = race_participation_repo.for_race(@race.id)
              render :new, status: :unprocessable_entity
            in Failure(error)
              flash.now[:alert] = "Error creating report: #{error.inspect}"
              @race_locations = race_location_repo.for_race(@race.id)
              @participations = race_participation_repo.for_race(@race.id)
              render :new, status: :unprocessable_entity
            end
          end

          def confirm
            result = Operations::Reports::Confirm.new.call(id: @report.id)

            case result
            in Success(report)
              redirect_to admin_race_report_path(@race, report),
                          notice: "Report confirmed."
            in Failure([ :invalid_status, message ])
              redirect_to admin_race_report_path(@race, @report),
                          alert: message
            in Failure(error)
              redirect_to admin_race_report_path(@race, @report),
                          alert: "Error confirming report: #{error.inspect}"
            end
          end

          def reject
            result = Operations::Reports::Reject.new.call(id: @report.id)

            case result
            in Success(report)
              redirect_to admin_race_report_path(@race, report),
                          notice: "Report rejected."
            in Failure([ :invalid_status, message ])
              redirect_to admin_race_report_path(@race, @report),
                          alert: message
            in Failure(error)
              redirect_to admin_race_report_path(@race, @report),
                          alert: "Error rejecting report: #{error.inspect}"
            end
          end

          def reopen
            result = Operations::Reports::Reopen.new.call(id: @report.id)

            case result
            in Success(report)
              redirect_to admin_race_report_path(@race, report),
                          notice: "Report reopened."
            in Failure(:already_pending)
              redirect_to admin_race_report_path(@race, @report),
                          alert: "Report is already pending review."
            in Failure(error)
              redirect_to admin_race_report_path(@race, @report),
                          alert: "Error reopening report: #{error.inspect}"
            end
          end

          private

          def set_race
            @race = Race.find(params[:race_id])
          end

          def set_report
            @report = report_repo.find!(params[:id])
          end

          def report_params
            params.require(:report).permit(
              :race_location_id,
              :race_participation_id,
              :bib_number,
              :athlete_position,
              :description
            )
          end

          def report_repo
            @report_repo ||= AppContainer["repos.report"]
          end

          def race_location_repo
            @race_location_repo ||= AppContainer["repos.race_location"]
          end

          def race_participation_repo
            @race_participation_repo ||= AppContainer["repos.race_participation"]
          end
        end
      end
    end
  end
end
