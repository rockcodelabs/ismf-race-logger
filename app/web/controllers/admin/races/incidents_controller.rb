# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      module Races
        # IncidentsController - Admin CRUD for incidents within a race
        #
        # Incidents are created by merging confirmed reports.
        # This controller handles:
        # - Listing all incidents for a race
        # - Viewing individual incident details
        # - Creating incidents (merging reports)
        # - Deciding incidents (approve/reject)
        # - Attaching penalties
        # - Reopening incidents
        #
        # Authorization:
        # - Admin and VAR Operator can manage incidents
        # - Referees can only view
        #
        # Pattern:
        # - Index: Use repo → summary structs (for lists)
        # - Show: Use repo → full struct (for detail)
        # - Create/Update: Use operations (business logic)
        #
        class IncidentsController < Admin::BaseController
          before_action :set_race
          before_action :set_incident, only: [ :show, :edit, :decide, :attach_penalties, :reopen ]

          def index
            @incidents = incident_repo.for_race(@race.id)
            @incidents = parts_factory.wrap_many(@incidents)
            @status_counts = incident_repo.count_by_status(@race.id)
          end

          def show
            @incident = parts_factory.wrap(@incident)
            @reports = report_repo.for_incident(@incident.id)
            @reports = parts_factory.wrap_many(@reports)
            @penalties = penalty_repo.all
          end

          def new
            # Get confirmed reports that are not yet linked to an incident
            @available_reports = report_repo.confirmed_without_incident(@race.id)
            @available_reports = parts_factory.wrap_many(@available_reports)

            if @available_reports.empty?
              redirect_to admin_race_incidents_path(@race),
                          alert: "No confirmed reports available to merge into an incident."
            end
          end

          def create
            report_ids = params[:report_ids]&.map(&:to_i) || []

            if report_ids.empty?
              flash.now[:alert] = "Please select at least one report."
              @available_reports = report_repo.confirmed_without_incident(@race.id)
              @available_reports = parts_factory.wrap_many(@available_reports)
              render :new, status: :unprocessable_entity
              return
            end

            result = Operations::Incidents::Create.new.call(
              report_ids: report_ids,
              description: params[:description]
            )

            case result
            in Success(incident)
              redirect_to admin_race_incident_path(@race, incident),
                          notice: "Incident created from #{report_ids.size} report(s)."
            in Failure([ :validation_failed, errors ])
              flash.now[:alert] = "Validation failed: #{errors.values.flatten.join(', ')}"
              @available_reports = report_repo.confirmed_without_incident(@race.id)
              @available_reports = parts_factory.wrap_many(@available_reports)
              render :new, status: :unprocessable_entity
            in Failure(error)
              flash.now[:alert] = "Error creating incident: #{error.inspect}"
              @available_reports = report_repo.confirmed_without_incident(@race.id)
              @available_reports = parts_factory.wrap_many(@available_reports)
              render :new, status: :unprocessable_entity
            end
          end

          def edit
            @incident = parts_factory.wrap(@incident)
            @reports = report_repo.for_incident(@incident.id)
            @reports = parts_factory.wrap_many(@reports)
            @penalties = penalty_repo.all
            @attached_penalty_ids = Incident.find(@incident.id).penalty_ids
          end

          def decide
            result = Operations::Incidents::Decide.new.call(
              id: @incident.id,
              status: params[:status],
              user_id: Current.user.id,
              description: params[:description],
              penalty_ids: params[:penalty_ids]&.map(&:to_i)
            )

            case result
            in Success(incident)
              status_label = incident.status == "approved" ? "approved" : "rejected"
              redirect_to admin_race_incident_path(@race, incident),
                          notice: "Incident #{status_label}."
            in Failure([ :validation_failed, errors ])
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: "Validation failed: #{errors.values.flatten.join(', ')}"
            in Failure(error)
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: "Error deciding incident: #{error.inspect}"
            end
          end

          def attach_penalties
            result = Operations::Incidents::AttachPenalties.new.call(
              incident_id: @incident.id,
              penalty_ids: params[:penalty_ids]&.map(&:to_i) || []
            )

            case result
            in Success(incident)
              redirect_to admin_race_incident_path(@race, incident),
                          notice: "Penalties updated."
            in Failure([ :validation_failed, errors ])
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: "Validation failed: #{errors.values.flatten.join(', ')}"
            in Failure(error)
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: "Error attaching penalties: #{error.inspect}"
            end
          end

          def reopen
            result = Operations::Incidents::Reopen.new.call(id: @incident.id)

            case result
            in Success(incident)
              redirect_to admin_race_incident_path(@race, incident),
                          notice: "Incident reopened."
            in Failure(:already_pending)
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: "Incident is already pending."
            in Failure(error)
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: "Error reopening incident: #{error.inspect}"
            end
          end

          private

          def set_race
            @race = Race.find(params[:race_id])
          end

          def set_incident
            @incident = incident_repo.find!(params[:id])
          end

          def incident_repo
            @incident_repo ||= AppContainer["repos.incident"]
          end

          def report_repo
            @report_repo ||= AppContainer["repos.report"]
          end

          def penalty_repo
            @penalty_repo ||= AppContainer["repos.penalty"]
          end
        end
      end
    end
  end
end
