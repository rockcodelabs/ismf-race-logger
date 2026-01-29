# frozen_string_literal: true

module Structs
  # Immutable representation of a RaceType record
  #
  # Used for single record operations (find, find!, find_by).
  #
  # @example
  #   struct = Structs::RaceType.new(
  #     id: 1,
  #     name: "Sprint",
  #     description: "Sprint race format with heats",
  #     created_at: Time.current,
  #     updated_at: Time.current
  #   )
  #
  class RaceType < DB::Struct
    # Required attributes
    attribute :id, Types::Integer
    attribute :name, Types::String
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    # Optional attributes
    attribute? :description, Types::String.optional

    # Domain methods

    def display_name
      name
    end

    def sprint?
      name == "Sprint"
    end

    def individual?
      name == "Individual"
    end

    def team?
      name == "Team"
    end

    def vertical?
      name == "Vertical"
    end

    def relay?
      name == "Mixed Relay"
    end
  end
end