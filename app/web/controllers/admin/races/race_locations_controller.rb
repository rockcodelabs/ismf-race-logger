# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      module Races
        # RaceLocationsController - Admin CRUD for race-specific locations
        #
        # Manages camera/observer positions for a specific race.
        # Routes are nested: /admin/races/:race_id/race_locations
        #
        # Locations are auto-populated from race type templates when race is created,
        # but admins can add custom locations (gates, cameras) per race.
        #
        # Permissions:
        # - Admins can create, edit, delete, reorder
        # - Cannot edit locations for completed races
        #
        # Pattern:
        # - Index: Use repos → structs (ordered by display_order)
        # - New/Create: Use operations (business logic + validation)
        # - Edit/Update: Use operations
        # - Destroy: Direct AR delete (simple operation)
        # - Reorder: Bulk update display_order values
        #
        class RaceLocationsController < Admin::BaseController
          before_action :set_race
          before_action :set_race_location, only: [:edit, :update, :destroy]
          after_action :verify_authorized

          # GET /admin/races/:race_id/race_locations
          # Displays locations ordered by display_order (chronological through race)
          def index
            authorize RaceLocation
            @locations = race_location_repo.for_race(@race.id)
            @standard_count = @locations.count(&:is_standard)
            @custom_count = @locations.count { |loc| !loc.is_standard }
          end

          # GET /admin/races/:race_id/race_locations/new
          def new
            authorize RaceLocation
            @location = {}
            @course_segments = course_segment_options
            @segment_positions = segment_position_options
            @color_codes = color_code_options
          end

          # POST /admin/races/:race_id/race_locations
          def create
            authorize RaceLocation

            result = Operations::RaceLocations::Create.new.call(
              race_id: @race.id,
              params: location_params.to_h.symbolize_keys
            )

            case result
            in Dry::Monads::Success(location)
              redirect_to admin_race_race_locations_path(@race),
                         notice: "Location '#{location.name}' was successfully added."
            in Dry::Monads::Failure([error_type, message])
              @course_segments = course_segment_options
              @segment_positions = segment_position_options
              @color_codes = color_code_options
              @errors = { error_type => [message] }
              flash.now[:alert] = message
              render :new, status: :unprocessable_entity
            end
          end

          # GET /admin/races/:race_id/race_locations/:id/edit
          def edit
            authorize @location
            @course_segments = course_segment_options
            @segment_positions = segment_position_options
            @color_codes = color_code_options
          end

          # PATCH/PUT /admin/races/:race_id/race_locations/:id
          def update
            authorize @location

            # Direct update for now (can create operation later if needed)
            race_location_record = RaceLocation.find(@location.id)
            
            if race_location_record.update(location_params)
              redirect_to admin_race_race_locations_path(@race),
                         notice: "Location '#{race_location_record.name}' was successfully updated."
            else
              @course_segments = course_segment_options
              @segment_positions = segment_position_options
              @color_codes = color_code_options
              @errors = race_location_record.errors.messages
              flash.now[:alert] = "Failed to update location: #{race_location_record.errors.full_messages.join(', ')}"
              render :edit, status: :unprocessable_entity
            end
          end

          # DELETE /admin/races/:race_id/race_locations/:id
          def destroy
            authorize @location

            race_location_record = RaceLocation.find(@location.id)
            name = race_location_record.name

            if race_location_record.destroy
              redirect_to admin_race_race_locations_path(@race),
                         notice: "Location '#{name}' was successfully deleted."
            else
              redirect_to admin_race_race_locations_path(@race),
                         alert: "Failed to delete location: #{race_location_record.errors.full_messages.join(', ')}"
            end
          end

          # POST /admin/races/:race_id/race_locations/reorder
          # Updates display_order for multiple locations
          def reorder
            authorize RaceLocation

            order_params = params[:order] || {}
            
            RaceLocation.transaction do
              order_params.each do |id, position|
                RaceLocation.where(id: id, race_id: @race.id).update_all(display_order: position)
              end
            end

            redirect_to admin_race_race_locations_path(@race),
                       notice: "Location order updated successfully."
          rescue StandardError => e
            redirect_to admin_race_race_locations_path(@race),
                       alert: "Failed to reorder locations: #{e.message}"
          end

          private

          def set_race
            @race = race_repo.find(params[:race_id])
            unless @race
              redirect_to admin_races_path, alert: "Race not found."
            end
          rescue ActiveRecord::RecordNotFound
            redirect_to admin_races_path, alert: "Race not found."
          end

          def set_race_location
            @location = race_location_repo.find(params[:id])
            unless @location && @location.race_id == @race.id
              redirect_to admin_race_race_locations_path(@race),
                         alert: "Location not found."
            end
          end

          def location_params
            params.require(:race_location).permit(
              :name,
              :course_segment,
              :segment_position,
              :display_order,
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

          def race_repo
            @race_repo ||= AppContainer["repos.race"]
          end

          def race_location_repo
            @race_location_repo ||= RaceLocationRepo.new
          end
        end
      end
    end
  end
end