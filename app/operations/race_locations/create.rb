# frozen_string_literal: true

module Operations
  module RaceLocations
    # Create Operation
    #
    # Creates a custom location for a specific race.
    # Used by admins to add race-specific locations (gates, cameras, etc.)
    # beyond the standard template locations.
    #
    # This operation:
    # 1. Validates the input parameters
    # 2. Calculates the next display_order (or uses provided order)
    # 3. Creates the race_location record
    # 4. Returns a struct (not the AR model)
    #
    # Returns:
    # - Success(Structs::RaceLocation) if location created
    # - Failure(:missing_name) if name not provided
    # - Failure(:missing_segment) if course_segment not provided
    # - Failure(:invalid_race) if race doesn't exist
    # - Failure(:validation_error) if record validation fails
    #
    # Example:
    #   result = Operations::RaceLocations::Create.new.call(
    #     race_id: 123,
    #     params: {
    #       name: "Gate 15",
    #       course_segment: "uphill2",
    #       segment_position: "middle",
    #       color_code: "green",
    #       description: "Technical gate section"
    #     }
    #   )
    #
    #   result.success?       # => true
    #   result.value!.name    # => "Gate 15"
    #
    class Create
      include Dry::Monads[:result]

      def initialize(race_location_repo: RaceLocationRepo.new)
        @race_location_repo = race_location_repo
      end

      def call(race_id:, params:)
        # Validate race exists
        unless Race.exists?(race_id)
          return Failure([:invalid_race, "Race with ID #{race_id} not found"])
        end

        # Validate required params
        return Failure([:missing_name, "Location name is required"]) unless params[:name].present?
        return Failure([:missing_segment, "Course segment is required"]) unless params[:course_segment].present?

        # Calculate next display_order if not provided
        display_order = if params[:display_order].present?
                          params[:display_order].to_i
                        else
                          @race_location_repo.max_display_order(race_id) + 10
                        end

        # Create the location
        location = RaceLocation.create!(
          race_id: race_id,
          name: params[:name],
          course_segment: params[:course_segment],
          segment_position: params[:segment_position] || "middle",
          display_order: display_order,
          is_standard: false, # Custom locations are never standard
          color_code: params[:color_code],
          description: params[:description]
        )

        # Return struct from repo
        Success(@race_location_repo.find(location.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([:validation_error, e.message])
      rescue StandardError => e
        Failure([:error, e.message])
      end
    end
  end
end