# frozen_string_literal: true

# Race model (associations only)
#
# A race is a specific competition event within a Competition.
# Each race has a type (individual, sprint, vertical, relay), stage (qualification, final),
# and scheduled time.
#
# Example:
#   Competition: "World Cup Verbier 2024"
#     Race 1: "Individual Qualification" (race_type: individual, stage: qualification)
#     Race 2: "Individual Final" (race_type: individual, stage: final)
#     Race 3: "Sprint Qualification" (race_type: sprint, stage: qualification)
#
# Associations:
# - belongs_to :competition
# - belongs_to :race_type
#
# Business logic lives in:
# - Operations: app/operations/races/
# - Repo: app/db/repos/race_repo.rb
# - Struct: app/db/structs/race.rb
#
class Race < ApplicationRecord
  belongs_to :competition
  belongs_to :race_type
end