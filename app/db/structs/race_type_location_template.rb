# frozen_string_literal: true

module Structs
  # RaceTypeLocationTemplate Struct
  #
  # Immutable domain object representing a location template for a race type.
  # Templates define standard and custom locations that are auto-populated when races are created.
  #
  # Standard locations (is_standard: true): Start, Finish, Transitions, segment markers
  # Custom locations (is_standard: false): Gates, Camera positions
  #
  class RaceTypeLocationTemplate < Dry::Struct
    attribute :id, IsmfRaceLogger::Types::Integer
    attribute :race_type_id, IsmfRaceLogger::Types::Integer
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

    # Returns true if this is a standard location (comes from official race type definition)
    def standard?
      is_standard
    end

    # Returns true if this is a custom location (gate, camera, etc.)
    def custom?
      !is_standard
    end

    # Returns CSS class for color indicator
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