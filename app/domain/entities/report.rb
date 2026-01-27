# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Domain
  module Entities
    class Report < Dry::Struct
      transform_keys(&:to_sym)

      # Required attributes - entities represent persisted domain objects
      attribute :id, Types::Integer
      attribute :client_uuid, Types::UUID
      attribute :race_id, Types::Integer
      attribute :user_id, Types::Integer
      attribute :bib_number, Types::BibNumber
      attribute :description, Types::String
      attribute :created_at, Types::FlexibleDateTime
      attribute :updated_at, Types::FlexibleDateTime
      
      # Optional attributes
      attribute? :incident_id, Types::Integer
      attribute? :race_location_id, Types::Integer
      attribute? :athlete_name, Types::String
      attribute? :video_url, Types::String

      # Business logic methods
      def has_video?
        !video_url.nil?
      end

      def athlete_display_name
        athlete_name || "Unknown Athlete"
      end

      def linked_to_incident?
        !incident_id.nil?
      end

      def from_fop_device?
        !client_uuid.nil?
      end
    end
  end
end