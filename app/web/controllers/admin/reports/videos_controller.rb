# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      module Reports
        # VideosController
        #
        # Handles video attachment to reports via Direct Upload.
        # Thin controller - delegates business logic to Operations::Reports::AttachVideos.
        #
        # Endpoints:
        #   POST /admin/races/:race_id/reports/:report_id/videos - Attach videos to a report
        #
        class VideosController < Web::Controllers::Admin::BaseController
          include Dry::Monads[:result]

          # POST /admin/races/:race_id/reports/:report_id/videos
          #
          # Attaches video blobs (from Direct Upload) to a report.
          #
          # Params:
          #   - blob_ids: Array of signed blob IDs from ActiveStorage Direct Upload
          #
          # Response:
          #   - 200 OK: Videos attached successfully
          #   - 404 Not Found: Report not found
          #   - 422 Unprocessable Entity: Validation failed
          #
          # DELETE /admin/races/:race_id/reports/:report_id/videos/:id
          #
          # Deletes a video attachment from a report.
          #
          # Params:
          #   - id: Attachment ID
          #
          # Response:
          #   - 200 OK: Video deleted successfully
          #   - 404 Not Found: Video attachment not found
          #
          def create
            result = Operations::Reports::AttachVideos.new.call(
              report_id: params[:report_id],
              blob_ids: blob_ids_param
            )

            if result.success?
              report_struct = result.value!
              
              # Broadcast update to all clients viewing this race
              report_broadcaster.videos_attached(report_struct)
              
              # Return video data for client-side caching
              videos_data = report_struct.videos.map do |video|
                {
                  id: video.id,
                  url: Rails.application.routes.url_helpers.rails_blob_url(video, only_path: false, host: request.base_url),
                  filename: video.filename.to_s,
                  size: video.byte_size,
                  content_type: video.content_type
                }
              end
              
              render json: { success: true, videos: videos_data }, status: :ok
            else
              error = result.failure
              
              case error
              when :not_found
                head :not_found
              when :missing_report_id, :missing_blob_ids, :empty_blob_ids
                render json: { error: "Invalid parameters" }, status: :bad_request
              when :blobs_not_found
                render json: { error: "One or more uploaded files not found" }, status: :unprocessable_entity
              when Hash
                if error.key?(:invalid_files)
                  render json: { errors: error[:invalid_files] }, status: :unprocessable_entity
                elsif error.key?(:validation_errors)
                  render json: { errors: error[:validation_errors] }, status: :unprocessable_entity
                elsif error.key?(:attachment_failed)
                  render json: { error: "Attachment failed: #{error[:attachment_failed]}" }, status: :internal_server_error
                else
                  render json: { error: "Unknown error" }, status: :internal_server_error
                end
              else
                render json: { error: "Unknown error" }, status: :internal_server_error
              end
            end
          end

          def destroy
            # Find the attachment
            attachment = ActiveStorage::Attachment.find_by(id: params[:id])
            
            if attachment.nil?
              head :not_found
              return
            end

            # Verify it belongs to the correct report
            unless attachment.record_type == 'Report' && attachment.record_id.to_s == params[:report_id]
              head :not_found
              return
            end

            # Get report struct before deletion
            report_id = attachment.record_id
            race_id = params[:race_id]

            # Delete the attachment
            attachment.purge

            # Reload report struct
            report_struct = ReportRepo.new.find(report_id)

            # Broadcast update to all clients viewing this race
            report_broadcaster.videos_attached(report_struct)

            head :ok
          rescue StandardError => e
            render json: { error: "Failed to delete video: #{e.message}" }, status: :internal_server_error
          end

          private

          # Extract blob_ids from params
          # Expects: { blob_ids: ["blob_1", "blob_2", ...] }
          def blob_ids_param
            params.fetch(:blob_ids, [])
          end

          # Access broadcaster via container
          def report_broadcaster
            @report_broadcaster ||= AppContainer["broadcasters.report"]
          end
        end
      end
    end
  end
end