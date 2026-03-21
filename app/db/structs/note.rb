# frozen_string_literal: true

module Structs
  # Immutable representation of a Note record
  #
  # Notes are polymorphic — they can be attached to Reports or Incidents.
  # Any authenticated user can create notes.
  #
  # @example
  #   note = Structs::Note.new(
  #     id: 1,
  #     notable_type: "Report",
  #     notable_id: 29,
  #     user_id: 5,
  #     user_name: "John Doe",
  #     body: "Reviewed video, confirmed contact.",
  #     created_at: Time.current,
  #     updated_at: Time.current
  #   )
  #
  class Note < DB::Struct
    attribute :id, Types::Integer
    attribute :notable_type, Types::String
    attribute :notable_id, Types::Integer
    attribute :user_id, Types::Integer
    attribute :body, Types::String
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    # Optional (from joins)
    attribute? :user_name, Types::String.optional

    # Domain methods

    def owned_by?(user_id_to_check)
      user_id == user_id_to_check
    end

    def for_report?
      notable_type == "Report"
    end

    def for_incident?
      notable_type == "Incident"
    end

    def edited?
      updated_at > created_at + 1.second
    end
  end
end