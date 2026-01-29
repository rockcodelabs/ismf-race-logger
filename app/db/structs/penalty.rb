# frozen_string_literal: true

module Structs
  # Immutable representation of a Penalty record
  #
  # Used for single record operations (find, find!, find_by).
  #
  # @example
  #   struct = Structs::Penalty.new(
  #     id: 1,
  #     category: "A",
  #     category_title: "General – infringements not specifically cited",
  #     category_description: "Used by ISMF Referee when...",
  #     penalty_number: "A.1",
  #     name: "Cheating, unsportsmanlike conduct or important safety fault",
  #     team_individual: "disqualification",
  #     vertical: "disqualification",
  #     sprint_relay: "disqualification",
  #     notes: nil,
  #     created_at: Time.current,
  #     updated_at: Time.current
  #   )
  #
  class Penalty < DB::Struct
    # Required attributes
    attribute :id, Types::Integer
    attribute :category, Types::String
    attribute :category_title, Types::String
    attribute :penalty_number, Types::String
    attribute :name, Types::String
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    # Optional attributes
    attribute? :category_description, Types::String.optional
    attribute? :team_individual, Types::String.optional
    attribute? :vertical, Types::String.optional
    attribute? :sprint_relay, Types::String.optional
    attribute? :notes, Types::String.optional

    # Domain methods

    def display_name
      "#{penalty_number} - #{name}"
    end

    def disqualification?
      team_individual == "disqualification" ||
        vertical == "disqualification" ||
        sprint_relay == "disqualification"
    end

    def time_penalty?
      !disqualification? && (team_individual.present? || vertical.present? || sprint_relay.present?)
    end

    def penalty_for_race_type(race_type)
      case race_type.downcase
      when "individual", "team"
        team_individual
      when "vertical"
        vertical
      when "sprint", "relay", "mixed relay"
        sprint_relay
      else
        "N/A"
      end
    end

    def category_letter
      category
    end
  end
end