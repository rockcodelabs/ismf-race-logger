# frozen_string_literal: true

module Infrastructure
  module Persistence
    module Records
      class RoleRecord < ApplicationRecord
        self.table_name = "roles"

        has_many :user_records,
                 class_name: "Infrastructure::Persistence::Records::UserRecord",
                 foreign_key: "role_id",
                 dependent: :nullify

        # NO validations (domain handles this)
        # NO callbacks
        # NO business logic

        # Simple scopes for data retrieval only
        scope :referee_roles, -> { where(name: %w[national_referee international_referee]) }
        scope :operator_roles, -> { where(name: "var_operator") }
        scope :by_name, ->(name) { find_by(name: name) }

        # Seed method (infrastructure concern)
        def self.seed_all!
          ROLE_NAMES.each { |name| find_or_create_by!(name: name) }
        end

        ROLE_NAMES = %w[
          var_operator
          national_referee
          international_referee
          jury_president
          referee_manager
          broadcast_viewer
        ].freeze
      end
    end
  end
end