# frozen_string_literal: true

module Structs
  # Summary Penalty struct for collections (lighter than full struct)
  #
  # Used by: all, by_category (collection queries)
  # Performance: Ruby Data.define (fast, immutable)
  #
  # Example:
  #   penalties = penalty_repo.all
  #   # => [Structs::PenaltySummary, Structs::PenaltySummary, ...]
  #
  #   penalties.each do |penalty|
  #     puts penalty.penalty_number
  #     puts penalty.name
  #     puts penalty.category
  #   end
  #
  PenaltySummary = Data.define(
    :id,
    :category,
    :category_title,
    :penalty_number,
    :name,
    :team_individual,
    :vertical,
    :sprint_relay
  ) do
    # Display name
    def display_name
      "#{penalty_number} - #{name}"
    end

    # Category letter
    def category_letter
      category
    end

    # Check if penalty is a disqualification
    def disqualification?
      team_individual == "disqualification" ||
        vertical == "disqualification" ||
        sprint_relay == "disqualification"
    end

    # Check if penalty is a time penalty
    def time_penalty?
      !disqualification? && (team_individual.present? || vertical.present? || sprint_relay.present?)
    end

    # Get penalty for specific race type
    def penalty_for_race_type(race_type)
      case race_type.to_s.downcase
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
  end
end