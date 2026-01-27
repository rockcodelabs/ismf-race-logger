# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Domain
  module ValueObjects
    class IncidentStatus < Dry::Struct
      attribute :value, Types::IncidentStatus

      UNOFFICIAL = new(value: "unofficial")
      OFFICIAL = new(value: "official")

      def unofficial?
        value == "unofficial"
      end

      def official?
        value == "official"
      end

      def can_transition_to?(new_status)
        case value
        when "unofficial"
          new_status == "official"
        when "official"
          false # Cannot transition from official back to unofficial
        else
          false
        end
      end

      def to_s
        value
      end

      def ==(other)
        case other
        when IncidentStatus
          value == other.value
        when String
          value == other
        else
          false
        end
      end
    end
  end
end
