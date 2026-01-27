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
        
        has_many :magic_link_records,
                 class_name: "Infrastructure::Persistence::Records::MagicLinkRecord",
                 foreign_key: "user_id",
                 dependent: :destroy
        
        belongs_to :role_record,
                   class_name: "Infrastructure::Persistence::Records::RoleRecord",
                   foreign_key: "role_id",
                   optional: true

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
      end
    end
  end
end