# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # CompetitionsController - Admin CRUD for competitions
      #
      # Uses repos for read operations (returning structs) and AR Competition model
      # for write operations (forms need AR objects for validation errors).
      #
      # Pattern:
      # - Index: Use repos → structs (immutable, presentation-ready)
      # - Show: Use repo → struct (display competition and races)
      # - New/Create/Update: Use AR model (form_with needs AR for errors)
      # - Destroy: Use AR model
      #
      # Note: We use explicit container access instead of Import[] because
      # Rails controllers have their own initialization requirements.
      #
      class CompetitionsController < BaseController
        before_action :set_competition, only: [ :show, :edit, :update, :destroy ]

        # GET /admin/competitions
        # Displays list with filtering (upcoming/ongoing/past), search, and sorting
        def index
          status_filter = params[:status]&.to_sym
          search_query = params[:search]
          
          @competitions = if search_query.present?
            competition_repo.search(search_query)
          elsif status_filter
            competition_repo.filtered(status: status_filter, sort: :recent)
          else
            competition_repo.all
          end

          @status_counts = competition_repo.count_by_status
        end

        # GET /admin/competitions/:id
        # Displays competition details with associated races grouped by race_type
        def show
          # Load full competition record for race count
          @competition_record = Competition.find(params[:id])
          
          # Load races as structs from repo
          races = race_repo.for_competition(@competition.id)
          
          # Group races by race_type_name for display
          @races_by_type = races.group_by(&:race_type_name)
        end

        # GET /admin/competitions/new
        def new
          @competition = Competition.new
        end

        # POST /admin/competitions
        def create
          @competition = Competition.new(competition_params)

          if @competition.save
            redirect_to admin_competition_path(@competition), 
                       notice: "Competition was successfully created."
          else
            render :new, status: :unprocessable_entity
          end
        end

        # GET /admin/competitions/:id/edit
        def edit
          # @competition is already set by before_action as struct (for display)
          # Load AR model for form_with into separate variable
          @competition_form = Competition.find(params[:id])
        end

        # PATCH/PUT /admin/competitions/:id
        def update
          competition_record = Competition.find(params[:id])
          
          if competition_record.update(competition_params)
            redirect_to admin_competition_path(competition_record), 
                       notice: "Competition was successfully updated."
          else
            # On validation error, set both variables for the edit view
            @competition = competition_repo.find!(params[:id])  # struct for display
            @competition_form = competition_record              # model for form
            render :edit, status: :unprocessable_entity
          end
        end

        # DELETE /admin/competitions/:id
        def destroy
          competition_record = Competition.find(params[:id])
          
          if competition_record.races.any?
            redirect_to admin_competitions_path, 
                       alert: "Cannot delete competition with existing races."
          else
            competition_record.destroy
            redirect_to admin_competitions_path, 
                       notice: "Competition was successfully deleted."
          end
        end

        private

        def set_competition
          @competition = competition_repo.find!(params[:id])
        end

        def competition_params
          params.require(:competition).permit(
            :name,
            :city,
            :place,
            :country,
            :description,
            :start_date,
            :end_date,
            :webpage_url,
            :logo
          )
        end

        def competition_repo
          @competition_repo ||= AppContainer["repos.competition"]
        end

        def race_repo
          @race_repo ||= AppContainer["repos.race"]
        end
      end
    end
  end
end