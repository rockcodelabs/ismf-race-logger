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
          include Dry::Monads[:result]

          before_action :set_race
          before_action :set_incident, only: [ :show, :edit, :update, :decide, :attach_penalties, :reopen, :add_reports, :remove_reports, :destroy ]
          before_action :set_source_incident, only: [ :merge ]

          def index
            # Unified UX: incidents list is now the reports list
            redirect_to admin_race_reports_path(@race), status: :moved_permanently
          end

          def show
            # Unified UX: incident show redirects to the primary report for this incident
            primary_report = Report.where(incident_id: @incident.id).order(:id).first
            if primary_report
              redirect_to admin_race_report_path(@race, primary_report), status: :moved_permanently
            else
              redirect_to admin_race_reports_path(@race), status: :moved_permanently
            end
          end

          def new
            authorize Incident, :create?
            # Get confirmed reports that are not yet linked to an incident
            @available_reports = report_repo.confirmed_without_incident(@race.id)
            @available_reports = parts_factory.wrap_many(@available_reports)

            if @available_reports.empty?
              redirect_to admin_race_incidents_path(@race),
                          alert: "No confirmed reports available to merge into an incident."
            end
          end

          def create
            authorize Incident, :create?
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

            if result.success?
              incident = result.value!
              redirect_to admin_race_incident_path(@race, incident),
                          notice: "Incident created from #{report_ids.size} report(s)."
            else
              error = result.failure
              if error.is_a?(Array) && error.first == :validation_failed
                flash.now[:alert] = "Validation failed: #{error.last.values.flatten.join(', ')}"
              else
                flash.now[:alert] = "Error creating incident: #{error.inspect}"
              end
              @available_reports = report_repo.confirmed_without_incident(@race.id)
              @available_reports = parts_factory.wrap_many(@available_reports)
              render :new, status: :unprocessable_entity
            end
          end

          def edit
            authorize @incident, :update?
            @incident = parts_factory.wrap(@incident)
            @reports = report_repo.for_incident(@incident.id)
            @reports = parts_factory.wrap_many(@reports)
            @penalties = penalty_repo.all
            @attached_penalty_ids = Incident.find(@incident.id).penalty_ids
          end

          def update
            authorize @incident, :update?
            
            # Only allow updating custom_name for now
            incident_record = Incident.find(@incident.id)
            
            respond_to do |format|
              if incident_record.update(incident_params)
                format.json { render json: { success: true, custom_name: incident_record.custom_name }, status: :ok }
                format.html do
                  redirect_to admin_race_incident_path(@race, incident_record),
                              notice: "Incident updated successfully."
                end
              else
                format.json { render json: { success: false, errors: incident_record.errors.full_messages }, status: :unprocessable_entity }
                format.html do
                  redirect_to admin_race_incident_path(@race, incident_record),
                              alert: "Failed to update incident."
                end
              end
            end
          end

          def decide
            authorize @incident, :decide?
            result = Operations::Incidents::Decide.new.call(
              id: @incident.id,
              status: params[:status],
              user_id: Current.user.id,
              description: params[:description],
              penalty_ids: params[:penalty_ids]&.map(&:to_i)
            )

            if result.success?
              incident = result.value!
              status_label = incident.status == "approved" ? "approved" : "rejected"
              
              # Broadcast removal of all reports that were confirmed/rejected
              # This updates touch displays by removing them from pending queue
              affected_reports = Report.where(incident_id: incident.id)
              affected_reports.each do |report|
                Turbo::StreamsChannel.broadcast_remove_to(
                  "race_#{@race.id}_reports",
                  target: "report_#{report.id}"
                )
              end
              
              # Broadcast updated report counters since reports were confirmed/rejected
              report_repo = AppContainer["repos.report"]
              status_counts = report_repo.count_by_status(@race.id)
              
              # Update report counters on touch displays
              Turbo::StreamsChannel.broadcast_action_to(
                "race_#{@race.id}_reports",
                action: :update,
                target: "pending-count-badge",
                html: status_counts["pending_review"] || 0
              )
              
              # Broadcast flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_notice(@race.id, "Incident #{status_label}.")
              
              # Also broadcast to reports stream if action came from reports page
              if params[:redirect_to_reports] == "true"
                report_broadcaster = AppContainer["broadcasters.report"]
                report_broadcaster.broadcast_flash_notice(@race.id, "Report and incident #{status_label}.")
              end
              
              # Check if request came from report page
              if params[:redirect_to_reports] == "true"
                redirect_to admin_race_reports_path(@race),
                            notice: "Incident #{status_label}."
              else
                redirect_to admin_race_incident_path(@race, incident),
                            notice: "Incident #{status_label}."
              end
            else
              error = result.failure
              error_message = if error.is_a?(Array) && error.first == :validation_failed
                "Validation failed: #{error.last.values.flatten.join(', ')}"
              else
                "Error deciding incident: #{error.inspect}"
              end
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)
              
              # Also broadcast to reports stream if action came from reports page
              if params[:redirect_to_reports] == "true"
                report_broadcaster = AppContainer["broadcasters.report"]
                report_broadcaster.broadcast_flash_alert(@race.id, error_message)
              end
              
              # Check if request came from report page
              if params[:redirect_to_reports] == "true" && params[:report_id].present?
                # Redirect back to the report page on error so user can fix validation
                redirect_to admin_race_report_path(@race, params[:report_id]), alert: error_message
              elsif params[:redirect_to_reports] == "true"
                # Fallback to reports index if report_id not provided
                redirect_to admin_race_reports_path(@race), alert: error_message
              else
                redirect_to admin_race_incident_path(@race, @incident), alert: error_message
              end
            end
          end

          def attach_penalties
            authorize @incident, :attach_penalties?

            # Filter out blank strings and convert to integers
            # Rails sends empty arrays as [""] which we need to handle
            penalty_ids = Array(params[:penalty_ids]).reject(&:blank?).map(&:to_i)

            result = Operations::Incidents::AttachPenalties.new.call(
              incident_id: @incident.id,
              penalty_ids: penalty_ids
            )

            if result.success?
              incident = result.value!
              
              # Broadcast flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_notice(@race.id, "Penalties updated.")
              
              redirect_to admin_race_incident_path(@race, incident),
                          notice: "Penalties updated."
            else
              error = result.failure
              error_message = if error.is_a?(Array) && error.first == :validation_failed
                "Validation failed: #{error.last.values.flatten.join(', ')}"
              else
                "Error attaching penalties: #{error.inspect}"
              end
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)
              
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: error_message
            end
          end

          def reopen
            authorize @incident, :reopen?
            result = Operations::Incidents::Reopen.new.call(id: @incident.id)

            if result.success?
              incident = result.value!
              
              # Broadcast flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_notice(@race.id, "Incident reopened.")
              
              redirect_to admin_race_incident_path(@race, incident),
                          notice: "Incident reopened."
            else
              error = result.failure
              error_message = if error == :already_pending
                "Incident is already pending."
              else
                "Error reopening incident: #{error.inspect}"
              end
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)
              
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: error_message
            end
          end

          def add_reports
            authorize @incident, :update?
            report_ids = params[:report_ids]&.map(&:to_i) || []

            if report_ids.empty?
              error_message = "No reports selected to add."
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)
              
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: error_message
              return
            end

            result = Operations::Incidents::AddReports.new.call(
              incident_id: @incident.id,
              report_ids: report_ids
            )

            if result.success?
              incident = result.value!
              success_message = "Added #{report_ids.size} report(s) to incident."
              
              # Broadcast flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_notice(@race.id, success_message)
              
              redirect_to admin_race_incident_path(@race, incident),
                          notice: success_message
            else
              error = result.failure
              error_message = case error
              in [:reports_not_found, missing_ids]
                "Reports not found: #{missing_ids.join(', ')}"
              in [:reports_already_linked, linked_ids]
                "Reports already linked to other incidents: #{linked_ids.join(', ')}"
              in [:no_reports_provided, message]
                message
              else
                "Error adding reports: #{error.inspect}"
              end
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)

              redirect_to admin_race_incident_path(@race, @incident),
                          alert: error_message
            end
          end

          def remove_reports
            authorize @incident, :update?
            report_ids = params[:report_ids]&.map(&:to_i) || []

            if report_ids.empty?
              error_message = "No reports selected to remove."
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)
              
              redirect_to admin_race_incident_path(@race, @incident),
                          alert: error_message
              return
            end

            result = Operations::Incidents::RemoveReports.new.call(
              incident_id: @incident.id,
              report_ids: report_ids
            )

            if result.success?
              incident = result.value!
              success_message = "Removed #{report_ids.size} report(s) from incident."
              
              # Broadcast flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_notice(@race.id, success_message)
              
              redirect_to admin_race_incident_path(@race, incident),
                          notice: success_message
            else
              error = result.failure
              error_message = case error
              in [:reports_not_found, missing_ids]
                "Reports not found: #{missing_ids.join(', ')}"
              in [:reports_not_in_incident, wrong_ids]
                "Reports not in this incident: #{wrong_ids.join(', ')}"
              in [:no_reports_provided, message]
                message
              else
                "Error removing reports: #{error.inspect}"
              end
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)

              redirect_to admin_race_incident_path(@race, @incident),
                          alert: error_message
            end
          end

          def merge
            authorize @source_incident, :update?
            authorize @incident, :update?

            merge_descriptions = params[:merge_descriptions] == "true" || params[:merge_descriptions] == "1"

            result = Operations::Incidents::Merge.new.call(
              source_incident_id: @source_incident.id,
              target_incident_id: @incident.id,
              merge_descriptions: merge_descriptions
            )

            if result.success?
              incident = result.value!
              
              # Broadcast flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_notice(@race.id, "Incidents merged successfully.")
              
              redirect_to admin_race_incident_path(@race, incident),
                          notice: "Incidents merged successfully."
            else
              error = result.failure
              error_message = case error
              in [:cannot_merge_self, message]
                message
              in [:different_races, message]
                message
              else
                "Error merging incidents: #{error.inspect}"
              end
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)

              redirect_to admin_race_incident_path(@race, @incident),
                          alert: error_message
            end
          end

          def delete_multiple
            authorize Incident, :destroy?
            
            incident_ids = params[:incident_ids]&.map(&:to_i) || []
            
            if incident_ids.empty?
              error_message = "No incidents selected to delete."
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)
              
              redirect_to admin_race_incidents_path(@race),
                          alert: error_message
              return
            end
            
            # Load incidents to check their status and reports
            incidents = Incident.where(id: incident_ids, race_id: @race.id)
            
            if incidents.count != incident_ids.size
              error_message = "Some incidents not found or don't belong to this race."
              
              # Broadcast error flash message to all connected clients
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.broadcast_flash_alert(@race.id, error_message)
              
              redirect_to admin_race_incidents_path(@race),
                          alert: error_message
              return
            end
            
            # Collect report and incident structs before deletion for broadcasting
            all_report_structs = []
            incident_structs = []
            
            incidents.each do |incident|
              # Collect incident struct
              incident_struct = incident_repo.find(incident.id)
              incident_structs << incident_struct if incident_struct
              
              # Collect report structs
              incident.reports.each do |report|
                report_struct = report_repo.find(report.id)
                all_report_structs << report_struct if report_struct
              end
            end
            
            # Delete incidents and their linked reports within transaction
            deleted_count = 0
            deleted_reports_count = 0
            
            ActiveRecord::Base.transaction do
              incidents.each do |incident|
                # Count and delete linked reports
                reports_count = incident.reports.count
                incident.reports.destroy_all
                deleted_reports_count += reports_count
                
                # Delete the incident
                incident.destroy
                deleted_count += 1
              end
            end
            
            # Broadcast deletions to all connected clients
            if all_report_structs.any?
              report_broadcaster = AppContainer["broadcasters.report"]
              report_broadcaster.bulk_deleted(all_report_structs, @race.id)
            end
            
            if incident_structs.any?
              incident_broadcaster.bulk_deleted(incident_structs, @race.id)
            end
            
            message = "Deleted #{deleted_count} incident#{deleted_count == 1 ? '' : 's'}"
            if deleted_reports_count > 0
              message += " and #{deleted_reports_count} linked report#{deleted_reports_count == 1 ? '' : 's'}"
            end
            message += " successfully."
            
            # Broadcast flash message to all connected clients
            incident_broadcaster.broadcast_flash_notice(@race.id, message)
            
            redirect_to admin_race_incidents_path(@race), notice: message
          rescue StandardError => e
            error_message = "Error deleting incidents: #{e.message}"
            
            # Broadcast error flash message to all connected clients
            incident_broadcaster = AppContainer["broadcasters.incident"]
            incident_broadcaster.broadcast_flash_alert(@race.id, error_message)
            
            redirect_to admin_race_incidents_path(@race),
                        alert: error_message
          end

          def destroy
            authorize @incident, :destroy?
            
            # Collect structs before deletion for broadcasting
            incident_struct = incident_repo.find(@incident.id)
            reports = Report.where(incident_id: @incident.id)
            report_structs = reports.map { |r| report_repo.find(r.id) }.compact
            reports_count = reports.count
            
            # Delete incident and its reports within transaction
            ActiveRecord::Base.transaction do
              reports.destroy_all
              Incident.find(@incident.id).destroy
            end
            
            # Broadcast deletions to all connected clients
            if report_structs.any?
              report_broadcaster = AppContainer["broadcasters.report"]
              report_broadcaster.bulk_deleted(report_structs, @race.id)
            end
            
            if incident_struct
              incident_broadcaster = AppContainer["broadcasters.incident"]
              incident_broadcaster.deleted(incident_struct)
            end
            
            message = "Deleted incident ##{@incident.id}"
            if reports_count > 0
              message += " and #{reports_count} linked report#{reports_count == 1 ? '' : 's'}"
            end
            message += " successfully."
            
            # Broadcast flash message to all connected clients
            incident_broadcaster = AppContainer["broadcasters.incident"]
            incident_broadcaster.broadcast_flash_notice(@race.id, message)
            
            redirect_to admin_race_incidents_path(@race), notice: message
          end

          private

          def set_race
            @race = Race.find(params[:race_id])
          end

          def set_incident
            @incident = incident_repo.find!(params[:id])
          end

          def set_source_incident
            @source_incident = incident_repo.find!(params[:source_incident_id])
            @incident = incident_repo.find!(params[:id])
          end

          def incident_repo
            @incident_repo ||= AppContainer["repos.incident"]
          end

          def incident_broadcaster
            @incident_broadcaster ||= AppContainer["broadcasters.incident"]
          end

          def report_repo
            @report_repo ||= AppContainer["repos.report"]
          end

          def penalty_repo
            @penalty_repo ||= AppContainer["repos.penalty"]
          end

          def note_repo
            @note_repo ||= AppContainer["repos.note"]
          end

          def incident_params
            params.require(:incident).permit(:custom_name)
          end
        end
      end
    end
  end
end
