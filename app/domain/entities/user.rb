# frozen_string_literal: true

require "dry-struct"
require_relative "../types"

module Domain
  module Entities
    class User < Dry::Struct
      transform_keys(&:to_sym)

      # Required attributes - entities represent persisted domain objects
      attribute :id, Types::Integer
      attribute :email_address, Types::Email
      attribute :name, Types::String
      attribute :admin, Types::Bool.default(false)
      attribute :created_at, Types::FlexibleDateTime
      attribute :updated_at, Types::FlexibleDateTime

      # Optional attributes
      attribute? :role_name, Types::RoleName.optional

      # Business logic methods
      def admin?
        admin
      end

      def display_name
        name.presence || email_address.split("@").first
      end

      # Role checking methods
      def var_operator?
        role_name == "var_operator"
      end

      def national_referee?
        role_name == "national_referee"
      end

      def international_referee?
        role_name == "international_referee"
      end

      def jury_president?
        role_name == "jury_president"
      end

      def referee_manager?
        role_name == "referee_manager"
      end

      def broadcast_viewer?
        role_name == "broadcast_viewer"
      end

      def referee?
        national_referee? || international_referee?
      end

      def has_role?(role_name_to_check)
        role_name == role_name_to_check.to_s
      end

      # Authorization helpers
      def can_officialize_incident?
        admin? || referee? || referee_manager?
      end

      def can_decide_incident?
        admin? || referee_manager? || international_referee?
      end

      def can_merge_incidents?
        admin? || referee_manager?
      end

      def can_manage_users?
        admin?
      end
    end
  end
end
