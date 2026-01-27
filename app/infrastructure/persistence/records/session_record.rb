# frozen_string_literal: true

module Infrastructure
  module Persistence
    module Records
      class SessionRecord < ApplicationRecord
        self.table_name = "sessions"

        belongs_to :user_record,
                   class_name: "Infrastructure::Persistence::Records::UserRecord",
                   foreign_key: "user_id"

        # Alias for convenience (Current.user delegates to session.user)
        alias_method :user, :user_record

        # NO validations (domain handles this)
        # NO callbacks
        # NO business logic

        # Simple scopes for data retrieval only
        scope :active, -> { where("expires_at > ?", Time.current) }
        scope :expired, -> { where("expires_at <= ?", Time.current) }
        scope :for_user, ->(user_id) { where(user_id: user_id) }
        scope :recent, -> { order(created_at: :desc) }
      end
    end
  end
end
