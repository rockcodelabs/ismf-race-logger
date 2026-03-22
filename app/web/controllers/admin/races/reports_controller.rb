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
          before_action :set_report, only: [ :show, :confirm, :reject, :reject_with_incident, :reopen, :video_thumbnails, :update_bib, :update_location ]

          # GET /admin/races/:race_id/reports/videos
          # Returns all videos for the race in JSON format for prefetching
          def videos_index
            authorize Report, :index?
            
            # Get all reports with videos for this race
            reports = report_repo.for_race(@race.id)
            
            videos = []
            reports.each do |report|
              # Get ActiveRecord model to access videos
              report_model = Report.includes(videos_attachments: :blob).find(report.id)
              
              report_model.videos.each do |video|
                videos << {
                  id: video.id,
                  url: Rails.application.routes.url_helpers.rails_blob_url(video, only_path: false, host: request.base_url),
                  filename: video.filename.to_s,
                  size: video.byte_size,
                  content_type: video.content_type,
                  report_id: report.id,
                  metadata: {
                    report_bib: report.bib_number,
                    report_status: report.status
                  }
                }
              end
            end
            
            render json: {
              race_id: @race.id,
              video_count: videos.length,
              videos: videos
            }
          end

          def index
            authorize Report, :index?

            # Filter by status (default to pending_review)
            # Uses visible_* methods which exclude secondary (merged) reports
            status = params[:status].presence || "pending_review"

            if status == "all"
              @reports = report_repo.visible_for_race(@race.id)
            else
              @reports = report_repo.visible_by_status(@race.id, status)
            end

            @reports = parts_factory.wrap_many(@reports)
            @status_counts = report_repo.visible_count_by_status(@race.id)

            # Load previous and next races for navigation
            all_races = race_repo.for_competition(@race.competition_id)
            current_index = all_races.find_index { |r| r.id == @race.id }
            @prev_race = current_index && current_index > 0 ? all_races[current_index - 1] : nil
            @next_race = current_index && current_index < all_races.length - 1 ? all_races[current_index + 1] : nil

            # Get all videos for this race for prefetch controller
            @race_videos = []
            report_repo.for_race(@race.id).each do |report|
              report_model = Report.includes(videos_attachments: :blob).find(report.id)
              report_model.videos.each do |video|
                @race_videos << {
                  id: video.id,
                  url: rails_blob_url(video, only_path: false, host: request.base_url)
                }
              end
            end

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

            # Load participations for bib selection and athlete change
            @participations = race_participation_repo.for_race(@race.id)

            # Load race locations for location change
            @race_locations = race_location_repo.for_race(@race.id)

            # Load notes for this report
            @notes = note_repo.for_notable("Report", @report.id)

            # Load incident data if report is linked to an incident
            if @report.incident_id.present?
              @incident = incident_repo.find(@report.incident_id)
              @penalties = penalty_repo.all

              # Get attached penalty IDs for pre-selecting in the form
              incident_model = Incident.includes(incident_penalties: :penalty).find(@report.incident_id)
              @attached_penalty_ids = incident_model.incident_penalties.map(&:penalty_id)

              # Load incident-level notes (post-confirmation)
              @incident_notes = note_repo.for_notable("Incident", @report.incident_id)

              # Load secondary reports (other reports grouped into the same incident)
              all_incident_reports = report_repo.for_incident(@report.incident_id)
              @merged_reports = parts_factory.wrap_many(
                all_incident_reports.reject { |r| r.id == @report.value.id }
              )

              # Reports available to merge into this incident (excluding already-linked ones)
              excluded = [ @report.value.id ] + all_incident_reports.map(&:id)
              @available_for_merge = parts_factory.wrap_many(
                report_repo.available_for_merge(@race.id, exclude_ids: excluded)
              )
            else
              # No incident yet — show reports that could be merged with this one
              @available_for_merge = parts_factory.wrap_many(
                report_repo.available_for_merge(@race.id, exclude_ids: [ @report.value.id ])
              )
            end
          end

          def new
            authorize Report, :create?
            @race_locations = race_location_repo.for_race(@race.id)
            @participations = race_participation_repo.for_race(@race.id)
          end

          def create
            authorize Report, :create?
            
            # Handle optional fields (NN support — empty string → nil)
            race_location_id = report_params[:race_location_id].present? ? report_params[:race_location_id].to_i : nil
            bib_number = report_params[:bib_number].present? ? report_params[:bib_number].to_i : nil
            race_participation_id = report_params[:race_participation_id].present? ? report_params[:race_participation_id].to_i : nil

            result = Operations::Reports::Create.new.call(
              race_id: @race.id,
              race_location_id: race_location_id,
              race_participation_id: race_participation_id,
              bib_number: bib_number,
              user_id: Current.user.id,
              athlete_position: report_params[:athlete_position]&.to_i,
              description: report_params[:description],
              client_uuid: report_params[:client_uuid]
            )

            respond_to do |format|
              if result.success?
                report = result.value!
                wrapped_report = parts_factory.wrap(report)
                
                # Broadcast to all connected clients (including the requesting device)
                report_broadcaster.created(report, @race.id)
                
                format.turbo_stream do
                  # Broadcast already sent to update all connected clients
                  redirect_to admin_race_report_path(@race, report),
                              notice: "Report created successfully.",
                              status: :see_other
                end
                
                format.html do
                  # Desktop: redirect to report show page
                  redirect_to admin_race_report_path(@race, report),
                              notice: "Report created successfully.",
                              status: :see_other
                end
              else
                error = result.failure
                error_message = if error.is_a?(Array) && error.first == :validation_failed
                  errors = error.last
                  "Validation failed: #{errors.values.flatten.join(', ')}"
                else
                  "Error creating report"
                end
                
                format.turbo_stream do
                  # Only errors are shown locally (not broadcasted)
                  render turbo_stream: turbo_stream.append("flash-messages",
                    partial: "shared/flash",
                    locals: { type: "alert", message: error_message }), status: :unprocessable_entity
                end
                
                format.html do
                  flash.now[:alert] = error_message
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

            respond_to do |format|
              if result.success?
                report = result.value!
                wrapped_report = parts_factory.wrap(report)
                
                # Broadcast to all connected clients (including the requesting device)
                report_broadcaster.confirmed(report, @race.id)
                
                format.turbo_stream do
                  # Broadcast already sent to update all connected clients
                  head :ok
                end
                
                format.html do
                  redirect_to admin_race_report_path(@race, report),
                              notice: "Report confirmed.",
                              status: :see_other
                end
              else
                error = result.failure
                error_message = error.is_a?(Array) && error.first == :invalid_status ? error.last : "Error confirming report"
                
                format.turbo_stream do
                  # Only errors are shown locally (not broadcasted)
                  render turbo_stream: turbo_stream.append("flash-messages",
                    partial: "shared/flash",
                    locals: { type: "alert", message: error_message })
                end
                
                format.html do
                  redirect_to admin_race_report_path(@race, @report),
                              alert: error_message
                end
              end
            end
          end

          def reject
            authorize @report, :reject?
            result = Operations::Reports::Reject.new.call(id: @report.id)

            respond_to do |format|
              if result.success?
                report = result.value!
                wrapped_report = parts_factory.wrap(report)
                
                # Broadcast to all connected clients (including the requesting device)
                report_broadcaster.rejected(report, @race.id)
                
                format.turbo_stream do
                  # Broadcast already sent to update all connected clients
                  head :ok
                end
                
                format.html do
                  redirect_to admin_race_report_path(@race, report),
                              notice: "Report rejected.",
                              status: :see_other
                end
              else
                error = result.failure
                error_message = error.is_a?(Array) && error.first == :invalid_status ? error.last : "Error rejecting report"
                
                format.turbo_stream do
                  # Only errors are shown locally (not broadcasted)
                  render turbo_stream: turbo_stream.append("flash-messages",
                    partial: "shared/flash",
                    locals: { type: "alert", message: error_message })
                end
                
                format.html do
                  redirect_to admin_race_report_path(@race, @report),
                              alert: error_message
                end
              end
            end
          end

          def reject_with_incident
            authorize @report, :reject?
            
            # Report must be linked to an incident
            unless @report.incident_id.present?
              redirect_to admin_race_report_path(@race, @report),
                          alert: "Report is not linked to an incident."
              return
            end
            
            # Load the incident
            incident = Incident.find_by(id: @report.incident_id)
            unless incident
              redirect_to admin_race_report_path(@race, @report),
                          alert: "Associated incident not found."
              return
            end
            
            # Call the incident decide operation with rejected status
            # This will reject the incident AND all associated pending reports
            result = Operations::Incidents::Decide.new.call(
              id: incident.id,
              status: "rejected",
              user_id: Current.user.id,
              description: params[:description],
              penalty_ids: []
            )
            
            if result.success?
              # Broadcast removal of all reports that were rejected
              # This updates touch displays by removing them from pending queue
              incident = Incident.find_by(id: incident.id)
              if incident
                affected_reports = Report.where(incident_id: incident.id)
                affected_reports.each do |report|
                  Turbo::StreamsChannel.broadcast_remove_to(
                    "race_#{@race.id}_reports",
                    target: "report_#{report.id}"
                  )
                end
              end
              
              # Broadcast updated report counters since reports were rejected
              status_counts = report_repo.count_by_status(@race.id)
              
              # Update report counters on touch displays
              Turbo::StreamsChannel.broadcast_action_to(
                "race_#{@race.id}_reports",
                action: :update,
                target: "pending-count-badge",
                html: status_counts["pending_review"] || 0
              )
              
              redirect_to admin_race_reports_path(@race),
                          notice: "Report and incident rejected.",
                          status: :see_other
            else
              error = result.failure
              error_message = if error.is_a?(Array) && error.first == :validation_failed
                "Validation failed: #{error.last.values.flatten.join(', ')}"
              else
                "Error rejecting incident: #{error.inspect}"
              end
              
              redirect_to admin_race_report_path(@race, @report),
                          alert: error_message
            end
          end

          def reopen
            authorize @report, :reopen?
            result = Operations::Reports::Reopen.new.call(id: @report.id)

            respond_to do |format|
              if result.success?
                report = result.value!
                wrapped_report = parts_factory.wrap(report)
                
                # Broadcast to all connected clients
                report_broadcaster.reopened(report, @race.id)
                
                format.turbo_stream do
                  render turbo_stream: [
                    turbo_stream.replace("report-status-badge", html: %{
                      <span id="report-status-badge" class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{wrapped_report.status_badge[:class]}">
                        #{wrapped_report.status_badge[:label]}
                      </span>
                    }.html_safe),
                    turbo_stream.replace("report-actions-card",
                      partial: "actions_card",
                      locals: { report: wrapped_report, race: @race }),
                    turbo_stream.append("flash-messages",
                      partial: "shared/flash",
                      locals: { type: "notice", message: "Report reopened." })
                  ]
                end
                
                format.html do
                  redirect_to admin_race_report_path(@race, report),
                              notice: "Report reopened.",
                              status: :see_other
                end
              else
                error = result.failure
                error_message = error == :already_pending ? "Report is already pending review." : "Error reopening report: #{error.inspect}"
                
                format.turbo_stream do
                  render turbo_stream: turbo_stream.append("flash-messages",
                    partial: "shared/flash",
                    locals: { type: "alert", message: error_message })
                end
                
                format.html do
                  redirect_to admin_race_report_path(@race, @report),
                              alert: error_message
                end
              end
            end
          end

          def update_bib
            authorize @report, :update?
            
            result = Operations::Reports::UpdateBib.new.call(
              report_id: @report.id,
              race_participation_id: params[:race_participation_id].to_i,
              bib_number: params[:bib_number].to_i
            )

            respond_to do |format|
              if result.success?
                report = result.value!
                
                # Broadcast update to all connected clients
                report_broadcaster.updated(report, @race.id)
                
                format.turbo_stream do
                  redirect_to admin_race_report_path(@race, @report),
                              notice: "Bib number updated successfully.",
                              status: :see_other
                end
                
                format.html do
                  redirect_to admin_race_report_path(@race, @report),
                              notice: "Bib number updated successfully.",
                              status: :see_other
                end
              else
                error = result.failure
                error_message = if error.is_a?(Array) && error.first == :validation_failed
                  errors = error.last
                  "Validation failed: #{errors.values.flatten.join(', ')}"
                else
                  "Error updating bib number"
                end
                
                format.turbo_stream do
                  render turbo_stream: turbo_stream.append("flash-messages",
                    partial: "shared/flash",
                    locals: { type: "alert", message: error_message }), status: :unprocessable_entity
                end
                
                format.html do
                  redirect_to admin_race_report_path(@race, @report),
                              alert: error_message,
                              status: :unprocessable_entity
                end
              end
            end
          end

          def update_location
            authorize @report, :update?

            race_location_id = params[:race_location_id].to_i
            report_model = Report.find(@report.id)

            if report_model.update(race_location_id: race_location_id)
              # Broadcast update to all connected clients
              updated_report = report_repo.find(@report.id)
              report_broadcaster.updated(updated_report, @race.id)

              redirect_to admin_race_report_path(@race, @report),
                          notice: "Location updated successfully.",
                          status: :see_other
            else
              redirect_to admin_race_report_path(@race, @report),
                          alert: "Error updating location.",
                          status: :unprocessable_entity
            end
          end

          def video_thumbnails
            authorize @report, :show?

            @report = parts_factory.wrap(@report)

            render partial: "video_thumbnails", locals: { report: @report, race: @race }
          end

          # POST /admin/races/:race_id/reports/merge
          # Merges 2+ reports into a single incident and redirects to the primary report.
          # Used from both the index (multi-select) and the show page (add another report).
          def merge
            authorize Report, :create?

            report_ids = params[:report_ids]&.map(&:to_i) || []

            if report_ids.size < 2
              redirect_to admin_race_reports_path(@race),
                          alert: "Please select at least 2 reports to merge."
              return
            end

            result = Operations::Incidents::Create.new.call(report_ids: report_ids)

            if result.success?
              incident = result.value!
              # Redirect to the primary report (lowest ID in the new incident)
              primary_report = Report.where(incident_id: incident.id).order(:id).first
              target = primary_report ? admin_race_report_path(@race, primary_report) : admin_race_reports_path(@race)
              redirect_to target, notice: "#{report_ids.size} reports merged successfully.", status: :see_other
            else
              error = result.failure
              error_message = if error.is_a?(Array) && error.first == :validation_failed
                "Validation failed: #{error.last.values.flatten.join(', ')}"
              else
                "Error merging reports: #{error.inspect}"
              end
              redirect_to admin_race_reports_path(@race), alert: error_message
            end
          end

          def delete_multiple
            authorize Report, :destroy?
            
            report_ids = params[:report_ids]&.map(&:to_i) || []
            
            if report_ids.empty?
              redirect_to admin_race_reports_path(@race),
                          alert: "No reports selected to delete."
              return
            end
            
            # Load reports to check which incidents they belong to
            reports = Report.where(id: report_ids, race_id: @race.id)
            
            if reports.count != report_ids.size
              redirect_to admin_race_reports_path(@race),
                          alert: "Some reports not found or don't belong to this race."
              return
            end
            
            # Convert to structs for broadcasting before deletion
            report_structs = reports.map { |r| report_repo.find(r.id) }
            
            # Track incident IDs before deletion
            incident_ids = reports.where.not(incident_id: nil).pluck(:incident_id).uniq
            
            # Delete reports within transaction
            deleted_count = 0
            ActiveRecord::Base.transaction do
              deleted_count = reports.destroy_all.size
              
              # Clean up empty incidents
              incident_ids.each do |incident_id|
                incident = Incident.find_by(id: incident_id)
                if incident && incident.reports.count == 0
                  incident.destroy
                end
              end
            end
            
            # Broadcast bulk deletion to all connected clients (touch displays)
            report_broadcaster.bulk_deleted(report_structs, @race.id)
            
            redirect_to admin_race_reports_path(@race),
                        notice: "Deleted #{deleted_count} report#{deleted_count == 1 ? '' : 's'} successfully."
          rescue StandardError => e
            redirect_to admin_race_reports_path(@race),
                        alert: "Error deleting reports: #{e.message}"
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

          def race_repo
            @race_repo ||= AppContainer["repos.race"]
          end

          def race_location_repo
            @race_location_repo ||= AppContainer["repos.race_location"]
          end

          def race_participation_repo
            @race_participation_repo ||= AppContainer["repos.race_participation"]
          end

          def report_broadcaster
            @report_broadcaster ||= AppContainer["broadcasters.report"]
          end

          def incident_repo
            @incident_repo ||= AppContainer["repos.incident"]
          end

          def penalty_repo
            @penalty_repo ||= AppContainer["repos.penalty"]
          end

          def note_repo
            @note_repo ||= AppContainer["repos.note"]
          end
        end
      end
    end
  end
end
