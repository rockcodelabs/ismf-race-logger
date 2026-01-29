# frozen_string_literal: true

module Structs
  # Summary RaceType struct for collections (lighter than full struct)
  #
  # Used by: all (collection queries)
  # Performance: Ruby Data.define (fast, immutable)
  #
  # Example:
  #   race_types = race_type_repo.all
  #   # => [Structs::RaceTypeSummary, Structs::RaceTypeSummary, ...]
  #
  #   race_types.each do |race_type|
  #     puts race_type.name
  #     puts race_type.description
  #   end
  #
  RaceTypeSummary = Data.define(
    :id,
    :name,
    :description
  ) do
    # Display name
    def display_name
      name
    end

    # Type predicates for conditional logic
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