# frozen_string_literal: true

# ActiveStorage configuration for video handling

Rails.application.config.after_initialize do
  # Enable video previews using ffmpeg
  # Generates thumbnail images from video files
  Rails.application.config.active_storage.video_preview_arguments =
    "-y -vframes 1 -f image2 -an"

  # Previewers for video files
  Rails.application.config.active_storage.previewers << ActiveStorage::Previewer::VideoPreviewer

  # Analyzers for extracting video metadata
  Rails.application.config.active_storage.analyzers << ActiveStorage::Analyzer::VideoAnalyzer

  # Set content types that should be considered as videos
  Rails.application.config.active_storage.content_types_to_serve_as_binary.delete("video/mp4")
  Rails.application.config.active_storage.content_types_allowed_inline << "video/mp4"

  # Variant processor (use vips for better performance, fallback to mini_magick)
  Rails.application.config.active_storage.variant_processor = :vips
end