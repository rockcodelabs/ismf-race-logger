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
          include Dry::Monads[:result]

          before_action :set_race
          before_action :set_report, only: [ :show, :confirm, :reject, :reopen ]

          def index
            authorize Report, :index?
            @reports = report_repo.for_race(@race.id)
            @reports = parts_factory.wrap_many(@reports)
            @status_counts = report_repo.count_by_status(@race.id)

            # Touch view needs locations and participations for the split-screen UI
            if touch_display?
              @race_locations = race_location_repo.for_race(@race.id)
              @participations = race_participation_repo.for_race(@race.id)
              # Note: participations are structs, not wrapped in parts (no Part class exists)
            end
          end

          def show
            authorize @report, :show?
            @report = parts_factory.wrap(@report)
          end

          def new
            authorize Report, :create?
            @race_locations = race_location_repo.for_race(@race.id)
            @participations = race_participation_repo.for_race(@race.id)
          end

          def create
            authorize Report, :create?
            result = Operations::Reports::Create.new.call(
              race_id: @race.id,
              race_location_id: report_params[:race_location_id].to_i,
              race_participation_id: report_params[:race_participation_id].to_i,
              bib_number: report_params[:bib_number].to_i,
              user_id: Current.user.id,
              athlete_position: report_params[:athlete_position]&.to_i,
              description: report_params[:description],
              client_uuid: report_params[:client_uuid]
            )

            if result.success?
              report = result.value!
              # Touch mode: redirect back to index to continue creating reports
              if touch_display?
                redirect_to admin_race_reports_path(@race),
                            notice: "Report ##{report.bib_number} created."
              else
                redirect_to admin_race_report_path(@race, report),
                            notice: "Report created successfully."
              end
            else
              error = result.failure
              if error.is_a?(Array) && error.first == :validation_failed
                errors = error.last
                if touch_display?
                  redirect_to admin_race_reports_path(@race),
                              alert: "Error: #{errors.values.flatten.join(', ')}"
                else
                  flash.now[:alert] = "Validation failed: #{errors.values.flatten.join(', ')}"
                  @race_locations = race_location_repo.for_race(@race.id)
                  @participations = race_participation_repo.for_race(@race.id)
                  render :new, status: :unprocessable_entity
                end
              else
                if touch_display?
                  redirect_to admin_race_reports_path(@race),
                              alert: "Error creating report"
                else
                  flash.now[:alert] = "Error creating report: #{error.inspect}"
                  @race_locations = race_location_repo.for_race(@race.id)
                  @participations = race_participation_repo.for_race(@race.id)
                  render :new, status: :unprocessable_entity
                end
              end
            end
          end

          def confirm
            authorize @report, :confirm?
            result = Operations::Reports::Confirm.new.call(id: @report.id)

            if result.success?
              report = result.value!
              if touch_display?
                redirect_to admin_race_reports_path(@race),
                            notice: "Report ##{report.bib_number} confirmed."
              else
                redirect_to admin_race_report_path(@race, report),
                            notice: "Report confirmed."
              end
            else
              error = result.failure
              redirect_path = touch_display? ? admin_race_reports_path(@race) : admin_race_report_path(@race, @report)
              if error.is_a?(Array) && error.first == :invalid_status
                redirect_to redirect_path, alert: error.last
              else
                redirect_to redirect_path, alert: "Error confirming report: #{error.inspect}"
              end
            end
          end

          def reject
            authorize @report, :reject?
            result = Operations::Reports::Reject.new.call(id: @report.id)

            if result.success?
              report = result.value!
              if touch_display?
                redirect_to admin_race_reports_path(@race),
                            notice: "Report ##{report.bib_number} rejected."
              else
                redirect_to admin_race_report_path(@race, report),
                            notice: "Report rejected."
              end
            else
              error = result.failure
              redirect_path = touch_display? ? admin_race_reports_path(@race) : admin_race_report_path(@race, @report)
              if error.is_a?(Array) && error.first == :invalid_status
                redirect_to redirect_path, alert: error.last
              else
                redirect_to redirect_path, alert: "Error rejecting report: #{error.inspect}"
              end
            end
          end

          def reopen
            authorize @report, :reopen?
            result = Operations::Reports::Reopen.new.call(id: @report.id)

            if result.success?
              report = result.value!
              redirect_to admin_race_report_path(@race, report),
                          notice: "Report reopened."
            else
              error = result.failure
              if error == :already_pending
                redirect_to admin_race_report_path(@race, @report),
                            alert: "Report is already pending review."
              else
                redirect_to admin_race_report_path(@race, @report),
                            alert: "Error reopening report: #{error.inspect}"
              end
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
              :description,
              :client_uuid
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
