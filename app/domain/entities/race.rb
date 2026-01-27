# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Domain
  module Entities
    class Race < Dry::Struct
      transform_keys(&:to_sym)

      # Required attributes - entities represent persisted domain objects
      attribute :id, Types::Integer
      attribute :name, Types::String
      attribute :race_date, Types::Params::Date
      attribute :location, Types::String
      attribute :status, Types::Strict::String.default("upcoming").enum("upcoming", "active", "completed")
      attribute :created_at, Types::FlexibleDateTime
      attribute :updated_at, Types::FlexibleDateTime

      # Status checks
      def upcoming?
        status == "upcoming"
      end

      def active?
        status == "active"
      end

      def completed?
        status == "completed"
      end

      # State transition checks
      def can_start?
        upcoming?
      end

      def can_complete?
        active?
      end

      def accepts_reports?
        active?
      end

      # Display helpers
      def display_date
        race_date.strftime("%Y-%m-%d")
      end

      def display_name
        "#{name} - #{location}"
      end

      def status_label
        status.capitalize
      end
    end
  end
end
