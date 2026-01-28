# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # Handles HTTP requests for {{Resources}}
      #
      # Follows thin controller pattern:
      # - Delegates business logic to Operations
      # - Uses Parts for presentation
      # - Resolves dependencies via AppContainer
      #
      class {{Resources}}Controller < Admin::BaseController
        # GET /admin/{{resources}}
        def index
          {{resources}} = {{resource}}_repo.all
          @{{resources}} = parts_factory.wrap_many({{resources}})
        end

        # GET /admin/{{resources}}/:id
        def show
          {{resource}} = {{resource}}_repo.find!(params[:id])
          @{{resource}} = parts_factory.wrap({{resource}})
        end

        # GET /admin/{{resources}}/new
        def new
          @{{resource}} = nil
        end

        # POST /admin/{{resources}}
        def create
          result = Operations::{{Resources}}::Create.new.call({{resource}}_params)

          case result
          in Success({{resource}})
            redirect_to admin_{{resource}}_path({{resource}}.id), notice: "{{Resource}} created successfully."
          in Failure(errors)
            @errors = errors
            render :new, status: :unprocessable_entity
          end
        end

        # GET /admin/{{resources}}/:id/edit
        def edit
          {{resource}} = {{resource}}_repo.find!(params[:id])
          @{{resource}} = parts_factory.wrap({{resource}})
        end

        # PATCH/PUT /admin/{{resources}}/:id
        def update
          result = Operations::{{Resources}}::Update.new.call(
            id: params[:id],
            params: {{resource}}_params
          )

          case result
          in Success({{resource}})
            redirect_to admin_{{resource}}_path({{resource}}.id), notice: "{{Resource}} updated successfully."
          in Failure(:not_found)
            head :not_found
          in Failure(errors)
            @errors = errors
            render :edit, status: :unprocessable_entity
          end
        end

        # DELETE /admin/{{resources}}/:id
        def destroy
          result = Operations::{{Resources}}::Delete.new.call(id: params[:id])

          case result
          in Success(_)
            redirect_to admin_{{resources}}_path, notice: "{{Resource}} deleted successfully."
          in Failure(:not_found)
            head :not_found
          end
        end

        private

        def {{resource}}_repo
          @{{resource}}_repo ||= AppContainer["repos.{{resource}}"]
        end

        def parts_factory
          @parts_factory ||= AppContainer["parts.factory"]
        end

        def {{resource}}_params
          params.require(:{{resource}}).permit(:name, :description, :status)
        end
      end
    end
  end
end

# Placeholders:
#   {{Resources}}  - Plural capitalized (e.g., Incidents)
#   {{resources}}  - Plural lowercase (e.g., incidents)
#   {{Resource}}   - Singular capitalized (e.g., Incident)
#   {{resource}}   - Singular lowercase (e.g., incident)
#
# Routes (add to config/routes.rb):
#   namespace :admin do
#     resources :{{resources}}
#   end