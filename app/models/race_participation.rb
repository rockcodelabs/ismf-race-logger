# frozen_string_literal: true

class RaceParticipation < ApplicationRecord
  belongs_to :race
  belongs_to :athlete
  belongs_to :team, optional: true

  # Validations are handled in Operations layer (Hanami-hybrid pattern)
  # Models only contain associations
end