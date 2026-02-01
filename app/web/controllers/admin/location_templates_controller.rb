# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # LocationTemplatesController - Unified view of all race location templates
      #
      # Provides a single page showing location templates across all race types.
      # This is the admin overview page for managing location templates.
      #
      # Route: /admin/location_templates
      #
      # Permissions:
      # - Only admins can view this page
      #
      class LocationTemplatesController < Admin::BaseController
        after_action :verify_authorized

        # GET /admin/location_templates
        # Displays all location templates grouped by race type
        def index
          authorize RaceTypeLocationTemplate

          # Fetch all race types
          @race_types = race_type_repo.all

          # Fetch all templates grouped by race type
          @templates_by_race_type = {}
          @race_types.each do |race_type|
            templates = template_repo.for_race_type(race_type.id)
            @templates_by_race_type[race_type.id] = {
              race_type: race_type,
              templates: templates,
              standard_count: templates.count(&:is_standard),
              custom_count: templates.count { |t| !t.is_standard }
            }
          end

          # Overall statistics
          all_templates = template_repo.all
          @total_templates = all_templates.count
          @total_standard = all_templates.count(&:is_standard)
          @total_custom = all_templates.count { |t| !t.is_standard }
        end

        private

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