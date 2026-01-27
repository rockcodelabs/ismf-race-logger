# frozen_string_literal: true

module Infrastructure
  module Persistence
    module Records
      class MagicLinkRecord < ApplicationRecord
        self.table_name = "magic_links"

        belongs_to :user_record,
                   class_name: "Infrastructure::Persistence::Records::UserRecord",
                   foreign_key: "user_id"

        # NO validations (domain handles this)
        # NO callbacks (application layer handles this)
        # NO business logic

        # Simple scopes for data retrieval only
        scope :valid, -> { where("expires_at > ?", Time.current).where(used_at: nil) }
        scope :expired, -> { where("expires_at <= ?", Time.current) }
        scope :used, -> { where.not(used_at: nil) }
        scope :for_user, ->(user_id) { where(user_id: user_id) }
        scope :by_token, ->(token) { find_by(token: token) }

        # Token generation (infrastructure concern)
        before_create :generate_token, if: -> { token.blank? }
        before_create :set_expiry, if: -> { expires_at.blank? }

        private

        def generate_token
          self.token = SecureRandom.urlsafe_base64(32)
        end

        def set_expiry
          self.expires_at = 24.hours.from_now
        end
      end
    end
  end
end