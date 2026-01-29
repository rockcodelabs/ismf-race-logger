# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # PenaltiesController - Admin interface for ISMF penalties reference
      #
      # This is a read-only controller - penalties are reference data seeded
      # from ISMF official rules and regulations.
      #
      # Pattern:
      # - Index: Use repos → structs (immutable, presentation-ready)
      #
      # Note: We use explicit container access instead of Import[] because
      # Rails controllers have their own initialization requirements.
      #
      class PenaltiesController < BaseController
        def index
          @penalties = penalty_repo.all
        end

        private

        def penalty_repo
          @penalty_repo ||= AppContainer["repos.penalty"]
        end
      end
    end
  end
end