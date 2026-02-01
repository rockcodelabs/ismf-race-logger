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
          def create
            result = Operations::Reports::AttachVideos.new.call(
              report_id: params[:report_id],
              blob_ids: blob_ids_param
            )

            if result.success?
              report_struct = result.value!
              
              # Broadcast update to all clients viewing this race
              report_broadcaster.videos_attached(report_struct)
              
              head :ok
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