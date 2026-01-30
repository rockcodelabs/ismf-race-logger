# frozen_string_literal: true

# Race Type Location Template
#
# Predefined location templates for each race type (Sprint, Individual, Vertical, Relay).
# These templates are used to auto-populate race_locations when a race is created.
#
# Standard locations (is_standard: true) are common positions like Start, Finish, Transitions.
# Custom locations (is_standard: false) are race-specific like Gates, Camera positions.
#
class RaceTypeLocationTemplate < ApplicationRecord
  belongs_to :race_type

  validates :name, presence: true
  validates :course_segment, presence: true
  validates :segment_position, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:display_order) }
  scope :standard, -> { where(is_standard: true) }
  scope :custom, -> { where(is_standard: false) }
end