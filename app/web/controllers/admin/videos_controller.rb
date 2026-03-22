# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # VideosController
      #
      # Handles video marker metadata (start_time, end_time) for ActiveStorage blobs.
      # Markers are stored in the blob's metadata JSON.
      #
      # Endpoints:
      #   POST   /admin/videos/markers       - Save time markers for a video
      #   GET    /admin/videos/markers/:id   - Get time markers for a video
      #
      class VideosController < Web::Controllers::Admin::BaseController
        include Dry::Monads[:result]

        # POST /admin/videos/markers
        def create_markers
          # Parse JSON body if present
          request_params = if request.content_type == "application/json"
            JSON.parse(request.body.read)
          else
            params
          end

          blob_id = request_params["blob_id"] || request_params[:blob_id]
          start_time = (request_params["start_time"] || request_params[:start_time]).to_f
          end_time = (request_params["end_time"] || request_params[:end_time]).to_f
          loop_enabled = request_params["loop_enabled"] || request_params[:loop_enabled] || false
          muted = request_params["muted"].nil? ? true : request_params["muted"]

          Rails.logger.info("Saving markers - blob_id: #{blob_id}, start: #{start_time}, end: #{end_time}, loop: #{loop_enabled}, muted: #{muted}")

          blob = ActiveStorage::Blob.find_by(id: blob_id)

          unless blob
            Rails.logger.error("Blob not found: #{blob_id}")
            render json: { error: "Video not found" }, status: :not_found
            return
          end

          # Update blob metadata with time markers
          blob.metadata["start_time"] = start_time
          blob.metadata["end_time"] = end_time
          blob.metadata["loop_enabled"] = loop_enabled
          blob.metadata["muted"] = muted
          blob.save!

          Rails.logger.info("Markers saved - metadata: #{blob.metadata.inspect}")

          render json: {
            success: true,
            start_time: blob.metadata["start_time"],
            end_time: blob.metadata["end_time"],
            loop_enabled: blob.metadata["loop_enabled"],
            muted: blob.metadata["muted"]
          }, status: :ok
        rescue StandardError => e
          Rails.logger.error("Failed to save video markers: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          render json: { error: "Failed to save markers: #{e.message}" }, status: :unprocessable_entity
        end

        # GET /admin/videos/markers/:id
        # Accepts either numeric blob ID or signed blob ID
        def show_markers
          blob = find_blob_by_id_or_signed(params[:id])

          unless blob
            render json: { error: "Video not found" }, status: :not_found
            return
          end

          render json: {
            start_time: blob.metadata["start_time"] || 0,
            end_time: blob.metadata["end_time"] || 0,
            loop_enabled: blob.metadata["loop_enabled"] || false,
            muted: blob.metadata["muted"].nil? ? true : blob.metadata["muted"]
          }, status: :ok
        rescue StandardError => e
          Rails.logger.error("Failed to load video markers: #{e.message}")
          render json: { error: "Failed to load markers" }, status: :unprocessable_entity
        end

        private

        # Try to find blob by numeric ID first, then by signed ID
        def find_blob_by_id_or_signed(id_param)
          # Try numeric ID first (from desktop player)
          if id_param.to_s.match?(/\A\d+\z/)
            blob = ActiveStorage::Blob.find_by(id: id_param)
            return blob if blob
          end

          # Try signed ID (from phone player URL extraction)
          ActiveStorage::Blob.find_signed(id_param)
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end
      end
    end
  end
end