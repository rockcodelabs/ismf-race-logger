# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      module RaceTypes
        # LocationTemplatesController - Admin CRUD for race type location templates
        #
        # Manages location templates for race types (Sprint, Individual, Vertical, etc.).
        # Routes are nested: /admin/race_types/:race_type_id/location_templates
        #
        # Templates define standard and custom locations that are auto-populated
        # when races of this type are created.
        #
        # Standard locations: Start, Finish, Transitions, segment markers
        # Custom locations: Gates, Camera positions
        #
        # Permissions:
        # - Only admins can create, edit, delete, reorder templates
        # - Changes affect future races only (existing races unchanged)
        #
        # Pattern:
        # - Index: Use repos → structs (ordered by display_order)
        # - New/Create: Use operations (business logic + validation)
        # - Edit/Update: Use operations
        # - Destroy: Direct AR delete (simple operation)
        # - Reorder: Bulk update display_order values
        #
        class LocationTemplatesController < Admin::BaseController
          before_action :set_race_type
          before_action :set_template, only: [:edit, :update, :destroy]
          after_action :verify_authorized

          # GET /admin/race_types/:race_type_id/location_templates
          # Displays templates ordered by display_order (chronological through race)
          def index
            authorize RaceTypeLocationTemplate
            @templates = template_repo.for_race_type(@race_type.id)
            @standard_count = @templates.count(&:is_standard)
            @custom_count = @templates.count { |t| !t.is_standard }
          end

          # GET /admin/race_types/:race_type_id/location_templates/new
          def new
            authorize RaceTypeLocationTemplate
            @template = {}
            @course_segments = course_segment_options
            @segment_positions = segment_position_options
            @color_codes = color_code_options
          end

          # POST /admin/race_types/:race_type_id/location_templates
          def create
            authorize RaceTypeLocationTemplate

            result = Operations::RaceTypeLocationTemplates::Create.new.call(
              race_type_id: @race_type.id,
              params: template_params.to_h.symbolize_keys
            )

            case result
            in Dry::Monads::Success(template)
              redirect_to admin_race_type_location_templates_path(@race_type),
                         notice: "Template '#{template.name}' was successfully added."
            in Dry::Monads::Failure([error_type, message])
              @course_segments = course_segment_options
              @segment_positions = segment_position_options
              @color_codes = color_code_options
              @errors = { error_type => [message] }
              flash.now[:alert] = message
              render :new, status: :unprocessable_entity
            end
          end

          # GET /admin/race_types/:race_type_id/location_templates/:id/edit
          def edit
            authorize @template
            @course_segments = course_segment_options
            @segment_positions = segment_position_options
            @color_codes = color_code_options
          end

          # PATCH/PUT /admin/race_types/:race_type_id/location_templates/:id
          def update
            authorize @template

            # Direct update for now (can create operation later if needed)
            template_record = RaceTypeLocationTemplate.find(@template.id)
            
            if template_record.update(template_params)
              redirect_to admin_race_type_location_templates_path(@race_type),
                         notice: "Template '#{template_record.name}' was successfully updated."
            else
              @course_segments = course_segment_options
              @segment_positions = segment_position_options
              @color_codes = color_code_options
              @errors = template_record.errors.messages
              flash.now[:alert] = "Failed to update template: #{template_record.errors.full_messages.join(', ')}"
              render :edit, status: :unprocessable_entity
            end
          end

          # DELETE /admin/race_types/:race_type_id/location_templates/:id
          def destroy
            authorize @template

            template_record = RaceTypeLocationTemplate.find(@template.id)
            name = template_record.name

            if template_record.destroy
              redirect_to admin_race_type_location_templates_path(@race_type),
                         notice: "Template '#{name}' was successfully deleted."
            else
              redirect_to admin_race_type_location_templates_path(@race_type),
                         alert: "Failed to delete template: #{template_record.errors.full_messages.join(', ')}"
            end
          end

          # POST /admin/race_types/:race_type_id/location_templates/reorder
          # Updates display_order for multiple templates
          def reorder
            authorize RaceTypeLocationTemplate

            order_params = params[:order] || {}
            
            RaceTypeLocationTemplate.transaction do
              order_params.each do |id, position|
                RaceTypeLocationTemplate.where(id: id, race_type_id: @race_type.id)
                                       .update_all(display_order: position)
              end
            end

            redirect_to admin_race_type_location_templates_path(@race_type),
                       notice: "Template order updated successfully."
          rescue StandardError => e
            redirect_to admin_race_type_location_templates_path(@race_type),
                       alert: "Failed to reorder templates: #{e.message}"
          end

          private

          def set_race_type
            @race_type = race_type_repo.find(params[:race_type_id])
            unless @race_type
              redirect_to admin_race_types_path, alert: "Race type not found."
            end
          rescue ActiveRecord::RecordNotFound
            redirect_to admin_race_types_path, alert: "Race type not found."
          end

          def set_template
            @template = template_repo.find(params[:id])
            unless @template && @template.race_type_id == @race_type.id
              redirect_to admin_race_type_location_templates_path(@race_type),
                         alert: "Template not found."
            end
          end

          def template_params
            params.require(:race_type_location_template).permit(
              :name,
              :course_segment,
              :segment_position,
              :display_order,
              :is_standard,
              :color_code,
              :description
            )
          end

          def course_segment_options
            [
              ['Start Area', 'start_area'],
              ['Uphill 1', 'uphill1'],
              ['Uphill 2', 'uphill2'],
              ['Uphill 3', 'uphill3'],
              ['Transition 1→2', 'transition_1to2'],
              ['Transition 2→1', 'transition_2to1'],
              ['Descent', 'descent'],
              ['Footpart', 'footpart'],
              ['Finish Area', 'finish_area']
            ]
          end

          def segment_position_options
            [
              ['Start', 'start'],
              ['Middle', 'middle'],
              ['Top', 'top'],
              ['Bottom', 'bottom'],
              ['End', 'end'],
              ['Full (entire segment)', 'full']
            ]
          end

          def color_code_options
            [
              ['None', ''],
              ['Green (Uphill)', 'green'],
              ['Red (Descent)', 'red'],
              ['Yellow (Footpart)', 'yellow']
            ]
          end

          def race_type_repo
            @race_type_repo ||= AppContainer["repos.race_type"]
          end

          def template_repo
            @template_repo ||= RaceTypeLocationTemplateRepo.new
          end
        end
      end
    end
  end
end