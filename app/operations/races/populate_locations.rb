# frozen_string_literal: true

module Operations
  module Races
    # PopulateLocations Operation
    #
    # Copies location templates from a race type to a specific race.
    # Called automatically when a race is created.
    #
    # This operation:
    # 1. Fetches all location templates for the race type
    # 2. Creates corresponding race_locations for the race
    # 3. Preserves all attributes (name, segment, order, color, etc.)
    #
    # Returns:
    # - Success(array of RaceLocation records) if templates copied
    # - Failure(:no_templates) if race type has no templates
    # - Failure(:validation_error) if location creation fails
    #
    # Example:
    #   result = Operations::Races::PopulateLocations.new.call(
    #     race_id: 123,
    #     race_type_id: 3
    #   )
    #
    #   result.success? # => true
    #   result.value!   # => [#<RaceLocation:0x...>, ...]
    #
    class PopulateLocations
      include Dry::Monads[:result]

      def initialize(template_repo: RaceTypeLocationTemplateRepo.new)
        @template_repo = template_repo
      end

      def call(race_id:, race_type_id:)
        # Fetch templates for this race type
        templates = @template_repo.for_race_type(race_type_id)

        if templates.empty?
          return Failure([:no_templates, "No location templates found for race type #{race_type_id}"])
        end

        # Create race_locations from templates
        locations = templates.map do |template|
          RaceLocation.create!(
            race_id: race_id,
            name: template.name,
            course_segment: template.course_segment,
            segment_position: template.segment_position,
            display_order: template.display_order,
            is_standard: template.is_standard,
            color_code: template.color_code,
            description: template.description
          )
        end

        Success(locations)
      rescue ActiveRecord::RecordInvalid => e
        Failure([:validation_error, e.message])
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end