# frozen_string_literal: true

# RaceTypeLocationTemplateRepo
#
# Repository for race type location templates.
# Provides query methods for retrieving location templates for race types.
#
# Returns:
# - Single records: Structs::RaceTypeLocationTemplate (full struct)
# - Collections: Structs::RaceTypeLocationTemplate (full struct, not summary - small dataset)
#
class RaceTypeLocationTemplateRepo < DB::Repo
  self.record_class = RaceTypeLocationTemplate
  self.struct_class = Structs::RaceTypeLocationTemplate

  returns_one :find, :find!
  returns_many :for_race_type, :standard, :custom, :all

  # Get all location templates for a specific race type, ordered by display_order
  def for_race_type(race_type_id)
    RaceTypeLocationTemplate
      .where(race_type_id: race_type_id)
      .order(:display_order)
      .map { |record| build_struct(record) }
  end

  # Get only standard locations for a race type
  def standard(race_type_id)
    RaceTypeLocationTemplate
      .where(race_type_id: race_type_id, is_standard: true)
      .order(:display_order)
      .map { |record| build_struct(record) }
  end

  # Get only custom locations for a race type
  def custom(race_type_id)
    RaceTypeLocationTemplate
      .where(race_type_id: race_type_id, is_standard: false)
      .order(:display_order)
      .map { |record| build_struct(record) }
  end

  # Get all templates across all race types (for admin overview)
  def all
    RaceTypeLocationTemplate
      .includes(:race_type)
      .order(:race_type_id, :display_order)
      .map { |record| build_struct(record) }
  end

  protected

  def base_scope
    RaceTypeLocationTemplate.all
  end

  def build_struct(record)
    Structs::RaceTypeLocationTemplate.new(
      id: record.id,
      race_type_id: record.race_type_id,
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

  # Not used for templates (small dataset, always use full struct)
  def build_summary(record)
    build_struct(record)
  end
end