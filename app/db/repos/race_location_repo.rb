# frozen_string_literal: true

# RaceLocationRepo
#
# Repository for race locations (camera/observer positions for specific races).
# Provides query methods for retrieving locations for races.
#
# Returns:
# - Single records: Structs::RaceLocation (full struct)
# - Collections: Structs::RaceLocation (full struct) or Structs::RaceLocationSummary (for touch UI)
#
class RaceLocationRepo < DB::Repo
  self.record_class = RaceLocation
  self.struct_class = Structs::RaceLocation
  self.summary_class = Structs::RaceLocationSummary

  returns_one :find, :find!
  returns_many :for_race, :for_touch_selector, :standard, :custom, :all

  # Get all locations for a specific race, ordered by display_order
  # Returns full structs (for admin UI, editing)
  def for_race(race_id)
    RaceLocation
      .where(race_id: race_id)
      .order(:display_order)
      .map { |record| build_struct(record) }
  end

  # Get locations for touch display selector (minimal data for performance)
  # Returns summary structs (for touch UI buttons)
  def for_touch_selector(race_id)
    RaceLocation
      .where(race_id: race_id)
      .order(:display_order)
      .map { |record| build_summary(record) }
  end

  # Get only standard locations for a race (from templates)
  def standard(race_id)
    RaceLocation
      .where(race_id: race_id, is_standard: true)
      .order(:display_order)
      .map { |record| build_struct(record) }
  end

  # Get only custom locations for a race (race-specific additions)
  def custom(race_id)
    RaceLocation
      .where(race_id: race_id, is_standard: false)
      .order(:display_order)
      .map { |record| build_struct(record) }
  end

  # Get all locations across all races (for admin overview)
  def all
    RaceLocation
      .includes(:race)
      .order(:race_id, :display_order)
      .map { |record| build_struct(record) }
  end

  # Find locations by race and course segment (e.g., all uphill1 locations)
  def by_segment(race_id, course_segment)
    RaceLocation
      .where(race_id: race_id, course_segment: course_segment)
      .order(:display_order)
      .map { |record| build_struct(record) }
  end

  # Get the maximum display_order for a race (for calculating next order)
  def max_display_order(race_id)
    RaceLocation.where(race_id: race_id).maximum(:display_order) || 0
  end

  protected

  def base_scope
    RaceLocation.all
  end

  def build_struct(record)
    Structs::RaceLocation.new(
      id: record.id,
      race_id: record.race_id,
      name: record.name,
      course_segment: record.course_segment,
      segment_position: record.segment_position,
      display_order: record.display_order,
      is_standard: record.is_standard,
      color_code: record.color_code,
      description: record.description,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  def build_summary(record)
    Structs::RaceLocationSummary.new(
      id: record.id,
      name: record.name,
      course_segment: record.course_segment,
      display_order: record.display_order,
      color_code: record.color_code
    )
  end
end