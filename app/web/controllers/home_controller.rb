# frozen_string_literal: true

module Web
  module Controllers
    class HomeController < ApplicationController
      allow_unauthenticated_access only: [ :index ]

      def index
      end
    end
  end
end
