# frozen_string_literal: true

module Infrastructure
  module Persistence
    module Records
      class UserRecord < ApplicationRecord
        self.table_name = "users"

        has_secure_password

        has_many :session_records, 
                 class_name: "Infrastructure::Persistence::Records::SessionRecord",
                 foreign_key: "user_id",
                 dependent: :destroy
        
        has_many :magic_links,
                 class_name: "Infrastructure::Persistence::Records::MagicLinkRecord",
                 foreign_key: "user_id",
                 dependent: :destroy
        
        belongs_to :role_record,
                   class_name: "Infrastructure::Persistence::Records::RoleRecord",
                   foreign_key: "role_id",
                   optional: true
        
        # Alias for convenience in factories and tests
        alias_method :role, :role_record
        alias_method :role=, :role_record=
        alias_method :sessions, :session_records

        # NO validations (domain handles this)
        # NO callbacks (application layer handles this)
        # NO business logic

        # Simple scopes for data retrieval only
        scope :ordered, -> { order(created_at: :desc) }
        scope :admins, -> { where(admin: true) }
        scope :with_role, ->(role_name) { 
          joins(:role_record).where(role_records: { name: role_name }) 
        }
        scope :referees, -> {
          joins(:role_record).where(role_records: { name: %w[national_referee international_referee] })
        }
        scope :by_email, ->(email) { where(email_address: email) }

        # Authenticate method for sessions (infrastructure concern)
        def self.authenticate_by(credentials)
          find_by(email_address: credentials[:email_address])
            &.authenticate(credentials[:password])
        end

        # Generate magic link for passwordless authentication
        def generate_magic_link!
          magic_links.create!
        end

        # Display name for views (convenience method from domain logic)
        def display_name
          name.presence || email_address.split("@").first
        end
      end
    end
  end
end