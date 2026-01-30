# frozen_string_literal: true

module Operations
  module Contracts
    # CreateRaceLocation Contract
    #
    # Validates input parameters for creating a race location.
    #
    # Required fields:
    # - race_id: integer
    # - name: string (location name)
    # - course_segment: string (must be valid CourseSegment enum value)
    # - segment_position: string (must be valid SegmentPosition enum value)
    #
    # Optional fields:
    # - display_order: integer
    # - color_code: string (must be valid ColorCode enum value)
    # - description: string
    #
    class CreateRaceLocation < Dry::Validation::Contract
      params do
        required(:race_id).filled(:integer)
        required(:name).filled(:string)
        required(:course_segment).filled(:string)
        required(:segment_position).filled(:string)
        optional(:display_order).maybe(:integer)
        optional(:color_code).maybe(:string)
        optional(:description).maybe(:string)
      end

      rule(:race_id) do
        key.failure("must be a valid race") unless Race.exists?(value)
      end

      rule(:course_segment) do
        valid_segments = %w[
          uphill1
          uphill2
          uphill3
          transition_1to2
          transition_2to1
          descent
          footpart
          start_area
          finish_area
        ]
        key.failure("must be one of: #{valid_segments.join(', ')}") unless valid_segments.include?(value)
      end

      rule(:segment_position) do
        valid_positions = %w[start middle top bottom end full]
        key.failure("must be one of: #{valid_positions.join(', ')}") unless valid_positions.include?(value)
      end

      rule(:color_code) do
        next if value.nil?

        valid_colors = %w[green red yellow]
        key.failure("must be one of: #{valid_colors.join(', ')}") unless valid_colors.include?(value)
      end

      rule(:display_order) do
        next if value.nil?

        key.failure("must be a positive integer") if value <= 0
      end
    end
  end
end