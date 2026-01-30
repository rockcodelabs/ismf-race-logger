# frozen_string_literal: true

module Structs
  # RaceLocationSummary Data Struct
  #
  # Lightweight summary for touch display location selector.
  # Uses Ruby Data.define for fast instantiation in collections.
  #
  # Used for:
  # - Touch display location buttons (minimal data for fast rendering)
  # - Location selector UI (no timestamps or descriptions needed)
  #
  RaceLocationSummary = Data.define(
    :id,
    :name,
    :course_segment,
    :display_order,
    :color_code
  ) do
    # Returns CSS class for color indicator badge
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
    # Large touch-friendly buttons with hover states
    def touch_button_class
      return "bg-gray-600 hover:bg-gray-700 active:bg-gray-800" if color_code.nil?

      case color_code
      when "green" then "bg-green-600 hover:bg-green-700 active:bg-green-800"
      when "red" then "bg-red-600 hover:bg-red-700 active:bg-red-800"
      when "yellow" then "bg-yellow-600 hover:bg-yellow-700 active:bg-yellow-800"
      when "blue" then "bg-blue-600 hover:bg-blue-700 active:bg-blue-800"
      when "gray" then "bg-gray-600 hover:bg-gray-700 active:bg-gray-800"
      else "bg-gray-600 hover:bg-gray-700 active:bg-gray-800"
      end
    end

    # Returns human-readable segment name for display
    def segment_display
      course_segment.gsub("_", " → ").titleize
    end
  end
end