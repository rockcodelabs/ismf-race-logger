# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # RacesController - Admin CRUD for races within competitions
      #
      # Races are always managed within the context of a competition.
      # Routes are nested: /admin/competitions/:competition_id/races
      #
      # Permissions:
      # - Admins and VAR Operators can create, edit, delete
      # - Cannot edit completed races
      # - Cannot change race_type if participants exist (future)
      #
      # Pattern:
      # - Index: Use repos → structs (grouped by race_type, ordered by schedule)
      # - Show: Use repo → struct (display race details)
      # - New/Create/Update: Use operations (business logic + validation)
      # - Destroy: Use operation
      #
      class RacesController < BaseController
        before_action :set_competition
        before_action :set_race, only: [ :show, :edit, :update, :destroy ]
        after_action :verify_authorized

        # GET /admin/competitions/:competition_id/races
        # Displays races grouped by race_type, ordered by schedule
        def index
          authorize Race
          @races = race_repo.for_competition(@competition.id)
          
          # Group races by race_type for display
          @races_by_type = @races.group_by(&:race_type_name)
        end

        # GET /admin/competitions/:competition_id/races/:id
        # Displays race details (for future: participants, reports, incidents)
        def show
          authorize @race
          # @race is already set by before_action as struct
          @participations = race_participation_repo.for_race(@race.id)
        end

        # GET /admin/competitions/:competition_id/races/new
        def new
          authorize Race
          # Simple hash for new form (Hanami pattern - no model needed)
          @race = {}
          @race_types = race_type_repo.all
          @stage_types = stage_type_options
          @heat_numbers = (1..10).to_a
        end

        # POST /admin/competitions/:competition_id/races
        def create
          authorize Race
          
          # Clean up params: convert empty strings to nil for optional fields
          cleaned_params = race_params.to_h.symbolize_keys
          cleaned_params[:heat_number] = nil if cleaned_params[:heat_number].blank?
          cleaned_params[:scheduled_at] = nil if cleaned_params[:scheduled_at].blank?
          
          result = Operations::Races::Create.new.call(
            competition_id: @competition.id,
            **cleaned_params
          )

          case result
          in Dry::Monads::Success(race)
            redirect_to admin_competition_races_path(@competition),
                       notice: "Race '#{race.name}' was successfully created."
          in Dry::Monads::Failure(errors)
            @race_types = race_type_repo.all
            @stage_types = stage_type_options
            @heat_numbers = (1..10).to_a
            @errors = errors
            flash.now[:alert] = format_errors(errors)
            render :new, status: :unprocessable_entity
          end
        end

        # GET /admin/competitions/:competition_id/races/:id/edit
        def edit
          authorize @race
          # @race is already a struct from set_race
          @race_types = race_type_repo.all
          @stage_types = stage_type_options
          @heat_numbers = (1..10).to_a
        end

        # PATCH/PUT /admin/competitions/:competition_id/races/:id
        def update
          authorize @race
          
          # Clean up params: convert empty strings to nil for optional fields
          cleaned_params = race_params.to_h.symbolize_keys
          cleaned_params[:heat_number] = nil if cleaned_params[:heat_number].blank?
          cleaned_params[:scheduled_at] = nil if cleaned_params[:scheduled_at].blank?
          
          result = Operations::Races::Update.new.call(
            id: @race.id,
            **cleaned_params
          )

          case result
          in Dry::Monads::Success(race)
            redirect_to admin_competition_races_path(@competition),
                       notice: "Race '#{race.name}' was successfully updated."
          in Dry::Monads::Failure(errors)
            @race_types = race_type_repo.all
            @stage_types = stage_type_options
            @heat_numbers = (1..10).to_a
            @errors = errors
            flash.now[:alert] = format_errors(errors)
            render :edit, status: :unprocessable_entity
          end
        end

        # DELETE /admin/competitions/:competition_id/races/:id
        def destroy
          authorize @race
          result = Operations::Races::Delete.new.call(id: @race.id)

          case result
          in Dry::Monads::Success
            redirect_to admin_competition_races_path(@competition),
                       notice: "Race '#{@race.name}' was successfully deleted."
          in Dry::Monads::Failure(errors)
            redirect_to admin_competition_races_path(@competition),
                       alert: "Failed to delete race: #{format_errors(errors)}"
          end
        end

        private

        def set_competition
          @competition = competition_repo.find!(params[:competition_id])
        rescue ActiveRecord::RecordNotFound
          redirect_to admin_competitions_path, alert: "Competition not found."
        end

        def set_race
          @race = race_repo.find(params[:id])
          unless @race && @race.competition_id == @competition.id
            redirect_to admin_competition_races_path(@competition),
                       alert: "Race not found."
          end
        end

        def race_params
          params.require(:race).permit(
            :race_type_id,
            :name,
            :stage_type,
            :heat_number,
            :scheduled_at,
            :position,
            :status
          )
        end

        def stage_type_options
          %w[Qualification Heat Quarterfinal Semifinal Final]
        end

        def format_errors(errors)
          return errors.to_s unless errors.is_a?(Hash)
          
          errors.map do |key, messages|
            messages = [messages] unless messages.is_a?(Array)
            "#{key.to_s.humanize}: #{messages.join(', ')}"
          end.join("; ")
        end

        def race_repo
          @race_repo ||= AppContainer["repos.race"]
        end

        def race_type_repo
          @race_type_repo ||= AppContainer["repos.race_type"]
        end

        def competition_repo
          @competition_repo ||= AppContainer["repos.competition"]
        end

        def race_participation_repo
          @race_participation_repo ||= AppContainer["repos.race_participation"]
        end
      end
    end
  end
end