# frozen_string_literal: true

module Web
  module Controllers
    class HomeController < ApplicationController
      allow_unauthenticated_access only: [ :index ]

      def index
        # Find closest active or upcoming competition for "Go to Competition" button
        @closest_competition = find_closest_competition
      end

      private

      def find_closest_competition
        # First check for ongoing competitions
        ongoing = competition_repo.ongoing.first
        return ongoing if ongoing

        # If no ongoing, get the next upcoming competition (soonest first)
        competition_repo.upcoming.first
      end

      def competition_repo
        @competition_repo ||= AppContainer["repos.competition"]
      end
    end
  end
end
