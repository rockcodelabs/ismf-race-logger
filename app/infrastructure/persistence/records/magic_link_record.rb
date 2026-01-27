# frozen_string_literal: true

module Infrastructure
  module Persistence
    module Records
      class MagicLinkRecord < ApplicationRecord
        self.table_name = "magic_links"

        # Associations
        belongs_to :user,
                   class_name: "Infrastructure::Persistence::Records::UserRecord",
                   foreign_key: "user_id",
                   required: true

        # Validations
        validates :token, uniqueness: true

        # Callbacks
        before_validation :generate_token, on: :create, if: -> { token.blank? }
        before_validation :set_expiry, on: :create, if: -> { expires_at.blank? }

        # Scopes
        scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
        scope :expired, -> { where("expires_at <= ?", Time.current) }
        scope :used, -> { where.not(used_at: nil) }
        scope :for_user, ->(user_id) { where(user_id: user_id) }

        # Instance methods
        def expired?
          expires_at <= Time.current
        end

        def used?
          used_at.present?
        end

        def valid_for_use?
          !expired? && !used?
        end

        def consume!
          return false unless valid_for_use?

          update(used_at: Time.current)
        end

        # Class methods
        def self.find_and_consume(token)
          link = valid.find_by(token: token)
          return nil unless link

          link.consume! ? link : nil
        end

        private

        def generate_token
          self.token = SecureRandom.urlsafe_base64(32)
        end

        def set_expiry
          self.expires_at = 15.minutes.from_now
        end
      end
    end
  end
end
