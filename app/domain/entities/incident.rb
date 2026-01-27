# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Domain
  module Entities
    class Incident < Dry::Struct
      transform_keys(&:to_sym)

      # Required attributes - entities represent persisted domain objects
      attribute :id, Types::Integer
      attribute :race_id, Types::Integer
      attribute :status, Types::IncidentStatus.default("unofficial")
      attribute :decision, Types::DecisionType.default("pending")
      attribute :created_at, Types::FlexibleDateTime
      attribute :updated_at, Types::FlexibleDateTime

      # Optional attributes
      attribute? :race_location_id, Types::Integer
      attribute? :officialized_by_user_id, Types::Integer
      attribute? :decided_by_user_id, Types::Integer
      attribute? :officialized_at, Types::FlexibleDateTime.optional
      attribute? :decided_at, Types::FlexibleDateTime.optional
      attribute? :decision_notes, Types::String

      # Status checks
      def unofficial?
        status == "unofficial"
      end

      def official?
        status == "official"
      end

      # Decision checks
      def pending?
        decision == "pending"
      end

      def decided?
        !pending?
      end

      def penalty_applied?
        decision == "penalty_applied"
      end

      def rejected?
        decision == "rejected"
      end

      def no_action?
        decision == "no_action"
      end

      # State transition checks
      def can_officialize?
        unofficial?
      end

      def can_decide?
        official? && pending?
      end

      def can_be_merged?
        unofficial? # Only merge unofficial incidents
      end

      # User authorization helpers
      def officialized_by?(user)
        officialized_by_user_id == user.id
      end

      def decided_by?(user)
        decided_by_user_id == user.id
      end

      # Workflow state
      def requires_decision?
        official? && pending?
      end

      def workflow_complete?
        official? && decided?
      end
    end
  end
end
