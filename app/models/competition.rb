# frozen_string_literal: true

# Competition model (associations only)
#
# A competition (e.g., "World Cup Verbier 2024") contains multiple races.
# Each race represents a specific race type and stage combination.
#
# Associations:
# - has_many :races (direct relationship, no stages table)
# - has_one_attached :logo (ActiveStorage)
#
# Business logic lives in:
# - Operations: app/operations/competitions/
# - Repo: app/db/repos/competition_repo.rb
# - Struct: app/db/structs/competition.rb
#
class Competition < ApplicationRecord
  has_many :races, dependent: :destroy
  has_one_attached :logo
end