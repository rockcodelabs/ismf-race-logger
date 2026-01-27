# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Domain
  module ValueObjects
    class UserRole < Dry::Struct
      attribute :name, Types::RoleName

      ROLE_HIERARCHY = {
        "broadcast_viewer" => 0,
        "var_operator" => 1,
        "national_referee" => 2,
        "international_referee" => 3,
        "jury_president" => 4,
        "referee_manager" => 5
      }.freeze

      def referee?
        name.in?(["national_referee", "international_referee"])
      end

      def operator?
        name == "var_operator"
      end

      def jury?
        name == "jury_president"
      end

      def manager?
        name == "referee_manager"
      end

      def viewer?
        name == "broadcast_viewer"
      end

      def can_officialize?
        referee? || manager? || jury?
      end

      def can_decide?
        international_referee? || manager? || jury?
      end

      def international_referee?
        name == "international_referee"
      end

      def level
        ROLE_HIERARCHY[name] || 0
      end

      def higher_than?(other_role)
        level > other_role.level
      end

      def to_s
        name.humanize
      end

      # Factory methods
      def self.var_operator
        new(name: "var_operator")
      end

      def self.national_referee
        new(name: "national_referee")
      end

      def self.international_referee
        new(name: "international_referee")
      end

      def self.jury_president
        new(name: "jury_president")
      end

      def self.referee_manager
        new(name: "referee_manager")
      end

      def self.broadcast_viewer
        new(name: "broadcast_viewer")
      end

      def self.all_roles
        Types::RoleName.values.map { |name| new(name: name) }
      end
    end
  end
end