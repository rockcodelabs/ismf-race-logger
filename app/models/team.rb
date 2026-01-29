# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :race
  belongs_to :athlete_1, class_name: "Athlete"
  belongs_to :athlete_2, class_name: "Athlete", optional: true
  has_one :race_participation, dependent: :destroy

  # Validations are handled in Operations layer (Hanami-hybrid pattern)
  # Models only contain associations
end