# frozen_string_literal: true

module Operations
  module RaceTypeLocationTemplates
    # Create Operation
    #
    # Creates a new location template for a race type.
    # Used by admins to add standard or custom template locations
    # that will be auto-populated when races of this type are created.
    #
    # This operation:
    # 1. Validates the input parameters
    # 2. Calculates the next display_order (or uses provided order)
    # 3. Creates the race_type_location_template record
    # 4. Returns a struct (not the AR model)
    #
    # Returns:
    # - Success(Structs::RaceTypeLocationTemplate) if template created
    # - Failure(:missing_name) if name not provided
    # - Failure(:missing_segment) if course_segment not provided
    # - Failure(:invalid_race_type) if race type doesn't exist
    # - Failure(:validation_error) if record validation fails
    #
    # Example:
    #   result = Operations::RaceTypeLocationTemplates::Create.new.call(
    #     race_type_id: 3,
    #     params: {
    #       name: "Gate 5",
    #       course_segment: "uphill2",
    #       segment_position: "middle",
    #       is_standard: false,
    #       color_code: "green",
    #       description: "Common gate position for Sprint races"
    #     }
    #   )
    #
    #   result.success?       # => true
    #   result.value!.name    # => "Gate 5"
    #
    class Create
      include Dry::Monads[:result]

      def initialize(template_repo: RaceTypeLocationTemplateRepo.new)
        @template_repo = template_repo
      end

      def call(race_type_id:, params:)
        # Validate race type exists
        unless RaceType.exists?(race_type_id)
          return Failure([:invalid_race_type, "Race type with ID #{race_type_id} not found"])
        end

        # Validate required params
        return Failure([:missing_name, "Location name is required"]) unless params[:name].present?
        return Failure([:missing_segment, "Course segment is required"]) unless params[:course_segment].present?

        # Calculate next display_order if not provided
        display_order = if params[:display_order].present?
                          params[:display_order].to_i
                        else
                          calculate_next_order(race_type_id)
                        end

        # Normalize empty strings to nil for optional fields
        color_code = params[:color_code].presence
        description = params[:description].presence



        # Create the template
        template = RaceTypeLocationTemplate.create!(
          race_type_id: race_type_id,
          name: params[:name],
          course_segment: params[:course_segment],
          segment_position: params[:segment_position] || "middle",
          display_order: display_order,
          is_standard: params[:is_standard] || false,
          color_code: color_code,
          description: description
        )

        # Return struct from repo
        Success(@template_repo.find(template.id))
      rescue ActiveRecord::RecordInvalid => e
        Failure([:validation_error, e.message])
      rescue StandardError => e
        Failure([:error, e.message])
      end

      private

      def calculate_next_order(race_type_id)
        existing = @template_repo.for_race_type(race_type_id)
        return 10 if existing.empty?

        existing.map(&:display_order).max + 10
      end
    end
  end
end