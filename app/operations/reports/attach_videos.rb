# frozen_string_literal: true

module Operations
  module Reports
    # AttachVideos Operation
    #
    # Attaches multiple video files to an existing report.
    # Validates file size (max 500MB) and content type (common video formats).
    #
    # Usage:
    #   operation = Operations::Reports::AttachVideos.new
    #   result = operation.call(report_id: 123, blob_ids: ["blob_1", "blob_2"])
    #
    #   case result
    #   in Success(report)
    #     # Videos attached successfully
    #   in Failure(:not_found)
    #     # Report not found
    #   in Failure(:invalid_files)
    #     # File validation failed
    #   in Failure(errors)
    #     # Validation errors hash
    #   end
    #
    class AttachVideos
      include Dry::Monads[:result, :do]
      include Import["repos.report"]

      # File size constraints (in bytes)
      MAX_FILE_SIZE = 500.megabytes
      ALLOWED_CONTENT_TYPES = [
        "video/mp4",
        "video/quicktime",
        "video/webm",
        "video/ogg",
        "video/x-msvideo",
        "video/avi"
      ].freeze

      # Attach videos to a report
      #
      # @param report_id [Integer] ID of the report
      # @param blob_ids [Array<String>] Array of signed blob IDs from Direct Upload
      # @return [Dry::Monads::Result] Success(report_struct) or Failure(reason)
      def call(report_id:, blob_ids:)
        yield validate_inputs(report_id, blob_ids)
        report_record = yield find_report(report_id)
        blobs = yield find_blobs(blob_ids)
        yield validate_blobs(blobs)
        yield attach_videos(report_record, blobs)

        Success(report.find(report_id))
      end

      private

      # Validate input parameters
      def validate_inputs(report_id, blob_ids)
        return Failure(:missing_report_id) if report_id.blank?
        return Failure(:missing_blob_ids) if blob_ids.blank? || !blob_ids.is_a?(Array)
        return Failure(:empty_blob_ids) if blob_ids.empty?

        Success(true)
      end

      # Find the report record
      def find_report(report_id)
        record = Report.find_by(id: report_id)
        record ? Success(record) : Failure(:not_found)
      end

      # Find all blob records from signed IDs
      def find_blobs(blob_ids)
        blobs = blob_ids.map do |signed_id|
          ActiveStorage::Blob.find_signed(signed_id)
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end.compact
        
        if blobs.count != blob_ids.count
          Failure(:blobs_not_found)
        else
          Success(blobs)
        end
      end

      # Validate blob files (size and content type)
      def validate_blobs(blobs)
        errors = []

        blobs.each do |blob|
          # Validate content type
          unless ALLOWED_CONTENT_TYPES.include?(blob.content_type)
            errors << "File '#{blob.filename}' has unsupported format (got: #{blob.content_type}). Supported: MP4, MOV, WebM, OGG, AVI"
          end

          # Validate file size (no minimum, only maximum)
          if blob.byte_size > MAX_FILE_SIZE
            errors << "File '#{blob.filename}' is too large (maximum: #{MAX_FILE_SIZE / 1.megabyte}MB)"
          end
        end

        if errors.any?
          Failure(invalid_files: errors)
        else
          Success(true)
        end
      end

      # Attach blobs to report
      def attach_videos(report_record, blobs)
        blobs.each do |blob|
          report_record.videos.attach(blob)
        end

        Success(true)
      rescue ActiveRecord::RecordInvalid => e
        Failure(validation_errors: e.record.errors.full_messages)
      rescue StandardError => e
        Failure(attachment_failed: e.message)
      end
    end
  end
end