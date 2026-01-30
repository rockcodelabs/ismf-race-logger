# frozen_string_literal: true

module Structs
  # RaceLocation Struct
  #
  # Immutable domain object representing a camera/observer location for a specific race.
  # Auto-populated from race_type_location_templates when race is created.
  # Can have additional race-specific custom locations added by admins.
  #
  # Standard locations (is_standard: true): Come from templates
  # Custom locations (is_standard: false): Race-specific additions
  #
  class RaceLocation < Dry::Struct
    attribute :id, IsmfRaceLogger::Types::Integer
    attribute :race_id, IsmfRaceLogger::Types::Integer
    attribute :name, IsmfRaceLogger::Types::String
    attribute :course_segment, IsmfRaceLogger::Types::CourseSegment
    attribute :segment_position, IsmfRaceLogger::Types::SegmentPosition
    attribute :display_order, IsmfRaceLogger::Types::Integer
    attribute :is_standard, IsmfRaceLogger::Types::Bool
    attribute :color_code, IsmfRaceLogger::Types::ColorCode.optional
    attribute :description, IsmfRaceLogger::Types::String.optional
    attribute :created_at, IsmfRaceLogger::Types::FlexibleDateTime
    attribute :updated_at, IsmfRaceLogger::Types::FlexibleDateTime

    # Returns display name with segment information for admin UI
    def display_name_with_segment
      "#{name} (#{course_segment.titleize})"
    end

    # Returns true if this is a standard location (from template)
    def standard?
      is_standard
    end

    # Returns true if this is a custom location (race-specific)
    def custom?
      !is_standard
    end

    # Returns CSS class for color indicator (for touch display)
    def css_color_class
      return "bg-gray-400" if color_code.nil?

      case color_code
      when "green" then "bg-green-500"
      when "red" then "bg-red-500"
      when "yellow" then "bg-yellow-500"
      when "blue" then "bg-blue-500"
      when "gray" then "bg-gray-500"
      else "bg-gray-400"
      end
    end

    # Returns Tailwind background color class for touch display buttons
    def touch_button_class
      return "bg-gray-600 hover:bg-gray-700" if color_code.nil?

      case color_code
      when "green" then "bg-green-600 hover:bg-green-700"
      when "red" then "bg-red-600 hover:bg-red-700"
      when "yellow" then "bg-yellow-600 hover:bg-yellow-700"
      when "blue" then "bg-blue-600 hover:bg-blue-700"
      when "gray" then "bg-gray-600 hover:bg-gray-700"
      else "bg-gray-600 hover:bg-gray-700"
      end
    end

    # Returns human-readable segment name
    def segment_display
      course_segment.gsub("_", " → ").titleize
    end

    # Returns human-readable position name
    def position_display
      segment_position.titleize
    end
  end
end