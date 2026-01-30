# frozen_string_literal: true

module ApplicationHelper
  # Returns Tailwind CSS classes for color badge based on color code
  # Used in location template and race location views
  #
  # @param color [String] Color code: 'green', 'red', 'yellow', or nil
  # @return [String] Tailwind CSS classes
  def color_badge_class(color)
    case color
    when 'green'
      'bg-green-100 text-green-800'
    when 'red'
      'bg-red-100 text-red-800'
    when 'yellow'
      'bg-yellow-100 text-yellow-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
