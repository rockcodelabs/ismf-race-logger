# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # ChunkedUploadsController
      #
      # Handles chunked video uploads with parallel chunk support.
      # Allows large video files to be uploaded in smaller chunks for better reliability
      # and resumability on mobile/unstable connections.
      #
      # Flow:
      #   1. POST /admin/chunked_uploads/initiate - Start chunked upload session
      #   2. POST /admin/chunked_uploads/chunk - Upload individual chunks (parallel)
      #   3. POST /admin/chunked_uploads/finalize - Assemble chunks into final blob
      #
      # Chunks are stored temporarily in storage/tmp/chunked_uploads/{upload_id}/
      # After finalization, chunks are assembled and deleted.
      #
      class ChunkedUploadsController < Web::Controllers::Admin::BaseController
        # POST /admin/chunked_uploads/initiate
        #
        # Initiates a new chunked upload session.
        #
        # Params:
        #   - filename: Original filename
        #   - content_type: MIME type
        #   - total_size: Total file size in bytes
        #   - total_chunks: Number of chunks to upload
        #
        # Response:
        #   {
        #     upload_id: "uuid-v4",
        #     chunk_size: 10485760,
        #     expires_at: "2024-01-15T12:00:00Z"
        #   }
        #
        def initiate
          upload_id = SecureRandom.uuid
          filename = params[:filename]
          content_type = params[:content_type]
          total_size = params[:total_size].to_i
          total_chunks = params[:total_chunks].to_i

          # Validate parameters
          if filename.blank? || content_type.blank? || total_size <= 0 || total_chunks <= 0
            render json: { error: "Invalid parameters" }, status: :bad_request
            return
          end

          # Create upload directory
          upload_dir = chunked_upload_path(upload_id)
          FileUtils.mkdir_p(upload_dir)

          # Store metadata
          metadata = {
            upload_id: upload_id,
            filename: filename,
            content_type: content_type,
            total_size: total_size,
            total_chunks: total_chunks,
            chunks_received: [],
            created_at: Time.current.iso8601,
            expires_at: 24.hours.from_now.iso8601
          }

          File.write(metadata_path(upload_id), metadata.to_json)

          render json: {
            upload_id: upload_id,
            chunk_size: 10 * 1024 * 1024, # 10MB recommended
            expires_at: metadata[:expires_at]
          }, status: :created
        end

        # POST /admin/chunked_uploads/chunk
        #
        # Uploads a single chunk.
        #
        # Params:
        #   - upload_id: Upload session ID
        #   - chunk_index: Chunk number (0-based)
        #   - chunk: File data (multipart)
        #
        # Response:
        #   { success: true, chunk_index: 0, received: 1, total: 5 }
        #
        def chunk
          upload_id = params[:upload_id]
          chunk_index = params[:chunk_index].to_i
          chunk_file = params[:chunk]

          # Validate parameters
          if upload_id.blank? || chunk_file.nil?
            render json: { error: "Invalid parameters" }, status: :bad_request
            return
          end

          # Verify upload session exists
          unless upload_exists?(upload_id)
            render json: { error: "Upload session not found" }, status: :not_found
            return
          end

          # Read metadata
          metadata = read_metadata(upload_id)

          # Validate chunk index
          if chunk_index < 0 || chunk_index >= metadata[:total_chunks]
            render json: { error: "Invalid chunk index" }, status: :bad_request
            return
          end

          # Save chunk to temporary storage
          chunk_path = chunk_file_path(upload_id, chunk_index)
          
          if chunk_file.respond_to?(:tempfile)
            FileUtils.mv(chunk_file.tempfile.path, chunk_path)
          else
            File.open(chunk_path, 'wb') do |file|
              file.write(chunk_file.read)
            end
          end

          # Update metadata with file locking to prevent race conditions
          File.open(metadata_path(upload_id), File::RDWR) do |file|
            file.flock(File::LOCK_EX)
            metadata = JSON.parse(file.read, symbolize_names: true)
            metadata[:chunks_received] << chunk_index unless metadata[:chunks_received].include?(chunk_index)
            metadata[:chunks_received].sort!
            file.rewind
            file.write(metadata.to_json)
            file.flush
            file.truncate(file.pos)
          end

          render json: {
            success: true,
            chunk_index: chunk_index,
            received: metadata[:chunks_received].length,
            total: metadata[:total_chunks]
          }, status: :ok
        rescue StandardError => e
          Rails.logger.error("Chunk upload failed: #{e.message}")
          render json: { error: "Chunk upload failed: #{e.message}" }, status: :internal_server_error
        end

        # POST /admin/chunked_uploads/finalize
        #
        # Assembles all chunks into a final ActiveStorage blob.
        #
        # Params:
        #   - upload_id: Upload session ID
        #
        # Response:
        #   { blob_id: "signed_blob_id", filename: "video.mp4", size: 52428800 }
        #
        def finalize
          upload_id = params[:upload_id]

          # Validate parameters
          if upload_id.blank?
            render json: { error: "Invalid parameters" }, status: :bad_request
            return
          end

          # Verify upload session exists
          unless upload_exists?(upload_id)
            render json: { error: "Upload session not found" }, status: :not_found
            return
          end

          # Read metadata
          metadata = read_metadata(upload_id)

          Rails.logger.info "🔍 Finalize upload #{upload_id}: received #{metadata[:chunks_received].length}/#{metadata[:total_chunks]} chunks"
          Rails.logger.info "📋 Chunks received: #{metadata[:chunks_received].inspect}"
          Rails.logger.info "📋 Expected chunks: #{(0...metadata[:total_chunks]).to_a.inspect}"

          # Verify all chunks received in metadata
          if metadata[:chunks_received].length != metadata[:total_chunks]
            missing_chunks = (0...metadata[:total_chunks]).to_a - metadata[:chunks_received]
            Rails.logger.error "❌ Missing chunks in metadata: #{missing_chunks.inspect}"
            
            render json: {
              error: "Not all chunks received",
              received: metadata[:chunks_received].length,
              total: metadata[:total_chunks],
              missing: missing_chunks
            }, status: :unprocessable_entity
            return
          end

          # Verify all chunk files actually exist on disk
          missing_files = []
          (0...metadata[:total_chunks]).each do |chunk_index|
            chunk_path = chunk_file_path(upload_id, chunk_index)
            unless File.exist?(chunk_path)
              missing_files << chunk_index
              Rails.logger.error "❌ Missing chunk file: #{chunk_path}"
            end
          end

          if missing_files.any?
            Rails.logger.error "❌ Missing chunk files: #{missing_files.inspect}"
            render json: {
              error: "Chunk files missing on disk",
              missing_files: missing_files
            }, status: :unprocessable_entity
            return
          end

          Rails.logger.info "✅ All chunks present, assembling..."

          # Assemble chunks into single file
          assembled_path = assemble_chunks(upload_id, metadata)

          # Create ActiveStorage blob
          blob = ActiveStorage::Blob.create_and_upload!(
            io: File.open(assembled_path),
            filename: metadata[:filename],
            content_type: metadata[:content_type]
          )

          # Cleanup temporary files
          cleanup_upload(upload_id, assembled_path)

          render json: {
            blob_id: blob.signed_id,
            filename: blob.filename.to_s,
            size: blob.byte_size,
            content_type: blob.content_type
          }, status: :ok
        rescue StandardError => e
          Rails.logger.error("Finalization failed: #{e.message}")
          cleanup_upload(upload_id)
          render json: { error: "Finalization failed: #{e.message}" }, status: :internal_server_error
        end

        # DELETE /admin/chunked_uploads/:upload_id
        #
        # Cancels a chunked upload session and deletes temporary files.
        #
        def destroy
          upload_id = params[:id]

          if upload_id.blank?
            render json: { error: "Invalid parameters" }, status: :bad_request
            return
          end

          cleanup_upload(upload_id)
          head :ok
        end

        private

        # Base path for chunked uploads
        def chunked_uploads_base_path
          Rails.root.join('storage', 'tmp', 'chunked_uploads')
        end

        # Path for specific upload session
        def chunked_upload_path(upload_id)
          chunked_uploads_base_path.join(upload_id)
        end

        # Path for metadata file
        def metadata_path(upload_id)
          chunked_upload_path(upload_id).join('metadata.json')
        end

        # Path for specific chunk
        def chunk_file_path(upload_id, chunk_index)
          chunked_upload_path(upload_id).join("chunk_#{chunk_index.to_s.rjust(4, '0')}")
        end

        # Check if upload session exists
        def upload_exists?(upload_id)
          File.exist?(metadata_path(upload_id))
        end

        # Read metadata from file
        def read_metadata(upload_id)
          JSON.parse(File.read(metadata_path(upload_id)), symbolize_names: true)
        end

        # Write metadata to file
        def write_metadata(upload_id, metadata)
          File.write(metadata_path(upload_id), metadata.to_json)
        end

        # Assemble chunks into single file
        def assemble_chunks(upload_id, metadata)
          assembled_path = chunked_upload_path(upload_id).join('assembled')

          File.open(assembled_path, 'wb') do |output|
            (0...metadata[:total_chunks]).each do |chunk_index|
              chunk_path = chunk_file_path(upload_id, chunk_index)
              
              unless File.exist?(chunk_path)
                raise "Missing chunk #{chunk_index}"
              end

              File.open(chunk_path, 'rb') do |chunk|
                IO.copy_stream(chunk, output)
              end
            end
          end

          # Verify assembled file size
          assembled_size = File.size(assembled_path)
          if assembled_size != metadata[:total_size]
            raise "Assembled file size mismatch: expected #{metadata[:total_size]}, got #{assembled_size}"
          end

          assembled_path
        end

        # Cleanup upload session files
        def cleanup_upload(upload_id, assembled_path = nil)
          upload_dir = chunked_upload_path(upload_id)
          
          # Delete assembled file if provided
          File.delete(assembled_path) if assembled_path && File.exist?(assembled_path)
          
          # Delete entire upload directory
          FileUtils.rm_rf(upload_dir) if File.exist?(upload_dir)
        rescue StandardError => e
          Rails.logger.error("Cleanup failed for upload #{upload_id}: #{e.message}")
        end
      end
    end
  end
end