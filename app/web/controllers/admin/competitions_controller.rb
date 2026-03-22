# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # CompetitionsController - Admin CRUD for competitions
      #
      # Uses operations with contracts for write operations (validation)
      # and repos for read operations (returning structs).
      #
      # Pattern:
      # - Index: Use repos → structs (immutable, presentation-ready)
      # - Show: Use repo → struct (display competition and races)
      # - New/Create: Use operation with contract validation
      # - Edit/Update: Use operation with contract validation
      # - Destroy: Use AR model (simple delete)
      #
      # Note: We use explicit container access instead of Import[] because
      # Rails controllers have their own initialization requirements.
      #
      class CompetitionsController < BaseController
        include Dry::Monads[:result]

        before_action :set_competition, only: [ :show, :edit, :update, :destroy ]

        # GET /admin/competitions
        # Displays list with filtering (upcoming/ongoing/past), search, and sorting
        def index
          authorize Competition, :index?
          status_filter = params[:status]&.to_sym
          search_query = params[:search]

          @competitions = if search_query.present?
            competition_repo.search(search_query)
          elsif status_filter
            competition_repo.filtered(status: status_filter, sort: :recent)
          else
            competition_repo.filtered(sort: :recent)
          end

          @status_counts = competition_repo.count_by_status
        end

        # GET /admin/competitions/:id
        # Displays competition details with associated races grouped by race_type
        def show
          authorize @competition, :show?
          # Load full competition record for race count
          @competition_record = Competition.find(params[:id])

          # Load races as structs from repo
          races = race_repo.for_competition(@competition.id)

          # Group by race type, sorted chronologically by the earliest scheduled_at
          # across all races in that type (regardless of status).
          grouped = races.group_by(&:race_type_name)
          @races_by_type = grouped.sort_by do |_type_name, type_races|
            type_races.map(&:scheduled_at).compact.min || Time.new(9999)
          end.to_h

          # Report counts per race — single query, no N+1
          @reports_count_by_race = report_repo.counts_for_races(races.map(&:id))
        end

        # GET /admin/competitions/new
        def new
          authorize Competition, :create?
          @competition = Competition.new
        end

        # POST /admin/competitions
        def create
          authorize Competition, :create?

          result = Operations::Competitions::Create.new.call(competition_params.to_h.symbolize_keys)

          if result.success?
            redirect_to admin_competition_path(result.value!),
                       notice: "Competition was successfully created."
          else
            @competition = Competition.new(competition_params)
            @errors = extract_errors(result.failure)
            flash.now[:alert] = format_errors(@errors)
            render :new, status: :unprocessable_entity
          end
        end

        # GET /admin/competitions/:id/edit
        def edit
          authorize @competition, :update?
          # @competition is already set by before_action as struct (for display)
          # Load AR model for form_with into separate variable
          @competition_form = Competition.find(params[:id])
        end

        # PATCH/PUT /admin/competitions/:id
        def update
          authorize @competition, :update?

          update_params = competition_params.to_h.symbolize_keys
          result = Operations::Competitions::Update.new.call(params[:id].to_i, update_params)

          if result.success?
            redirect_to admin_competition_path(result.value!),
                       notice: "Competition was successfully updated."
          else
            @competition = competition_repo.find!(params[:id])  # struct for display
            @competition_form = Competition.find(params[:id])   # model for form
            @errors = extract_errors(result.failure)
            flash.now[:alert] = format_errors(@errors)
            render :edit, status: :unprocessable_entity
          end
        end

        # DELETE /admin/competitions/:id
        def destroy
          authorize @competition, :destroy?
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

        def extract_errors(failure)
          case failure
          in [:validation_failed, errors]
            errors
          in [:database_error, message]
            { database: [message] }
          in [:not_found, message]
            { record: [message] }
          in [:unexpected_error, message]
            { error: [message] }
          else
            { error: [failure.to_s] }
          end
        end

        def format_errors(errors)
          return errors.to_s unless errors.is_a?(Hash)

          errors.map do |key, messages|
            messages = [messages] unless messages.is_a?(Array)
            "#{key.to_s.humanize}: #{messages.join(', ')}"
          end.join("; ")
        end

        def competition_repo
          @competition_repo ||= AppContainer["repos.competition"]
        end

        def race_repo
          @race_repo ||= AppContainer["repos.race"]
        end

        def report_repo
          @report_repo ||= AppContainer["repos.report"]
        end
      end
    end
  end
end