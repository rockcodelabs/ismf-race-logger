# frozen_string_literal: true

class Athlete < ApplicationRecord
  has_many :race_participations, dependent: :destroy
  has_many :races, through: :race_participations
  has_many :teams_as_athlete_1, class_name: "Team", foreign_key: :athlete_1_id, dependent: :destroy, inverse_of: :athlete_1
  has_many :teams_as_athlete_2, class_name: "Team", foreign_key: :athlete_2_id, dependent: :nullify, inverse_of: :athlete_2

  # Validations are handled in Operations layer (Hanami-hybrid pattern)
  # Models only contain associations
end