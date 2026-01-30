# frozen_string_literal: true

# Race Location
#
# Actual camera/observer positions for a specific race.
# Auto-populated from race_type_location_templates when race is created.
# Can have additional race-specific custom locations added by admins.
#
# Standard locations (is_standard: true) come from templates.
# Custom locations (is_standard: false) are race-specific additions.
#
class RaceLocation < ApplicationRecord
  belongs_to :race
  before_validation :normalize_optional_fields

  # has_many :reports, dependent: :nullify  # TODO: Uncomment when Report model is created
  # has_many :incidents, dependent: :nullify  # TODO: Uncomment when Incident model is created

  validates :name, presence: true
  validates :course_segment, presence: true
  validates :segment_position, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:display_order) }
  scope :standard, -> { where(is_standard: true) }
  scope :custom, -> { where(is_standard: false) }

  private

  def normalize_optional_fields
    self.color_code = nil if color_code.blank?
    self.description = nil if description.blank?
  end
end