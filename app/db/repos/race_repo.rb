# frozen_string_literal: true

# Repository for Race persistence operations
#
# Returns Structs::Race for single records, Structs::RaceSummary for collections
#
# Usage:
#   repo = AppContainer["repos.race"]
#   repo.find(1)                    # => Structs::Race or nil
#   repo.for_competition(1)         # => [Structs::RaceSummary, ...]
#   repo.by_race_type(1, 1)         # => [Structs::RaceSummary, ...]
#   repo.scheduled                  # => [Structs::RaceSummary, ...]
#   repo.in_progress                # => [Structs::RaceSummary, ...]
#
class RaceRepo < DB::Repo
  # Configure the repo
  self.record_class = Race

  # Declare which custom methods return single vs. collection
  returns_one :find, :find!, :find_by, :create, :update
  returns_many :all, :for_competition, :by_race_type, :scheduled, :in_progress, :completed, :auto_startable, :auto_completable

  # --- Single Record Methods ---

  # Find race by ID
  # @param id [Integer]
  # @return [Structs::Race, nil]
  def find(id)
    record = base_scope.find_by(id: id)
    record ? build_struct(record) : nil
  end

  # Find race by ID (raises if not found)
  # @param id [Integer]
  # @return [Structs::Race]
  # @raise [ActiveRecord::RecordNotFound]
  def find!(id)
    record = base_scope.find(id)
    build_struct(record)
  end

  # Find race by attributes
  # @param attrs [Hash]
  # @return [Structs::Race, nil]
  def find_by(attrs)
    record = base_scope.find_by(attrs)
    record ? build_struct(record) : nil
  end

  # Create a new race
  # @param attrs [Hash]
  # @return [Structs::Race]
  def create(attrs)
    record = Race.create!(attrs)
    build_struct(base_scope.find(record.id))
  end

  # Update a race
  # @param id [Integer]
  # @param attrs [Hash]
  # @return [Structs::Race]
  def update(id, attrs)
    record = Race.find(id)
    record.update!(attrs)
    build_struct(base_scope.find(id))
  end

  # Delete a race
  # @param id [Integer]
  # @return [Boolean]
  def delete(id)
    Race.find(id).destroy!
    true
  end

  # --- Collection Methods ---

  # Get all races for a competition, grouped by race type and ordered by schedule
  # @param competition_id [Integer]
  # @return [Array<Structs::RaceSummary>]
  def for_competition(competition_id)
    base_scope
      .where(competition_id: competition_id)
      .order(:race_type_id, :position, :scheduled_at)
      .map { |r| build_summary(r) }
  end

  # Get races for a competition filtered by race type
  # @param competition_id [Integer]
  # @param race_type_id [Integer]
  # @return [Array<Structs::RaceSummary>]
  def by_race_type(competition_id, race_type_id)
    base_scope
      .where(competition_id: competition_id, race_type_id: race_type_id)
      .order(:position, :scheduled_at)
      .map { |r| build_summary(r) }
  end

  # Get scheduled races
  # @return [Array<Structs::RaceSummary>]
  def scheduled
    base_scope
      .where(status: "scheduled")
      .order(:scheduled_at)
      .map { |r| build_summary(r) }
  end

  # Get races currently in progress
  # @return [Array<Structs::RaceSummary>]
  def in_progress
    base_scope
      .where(status: "in_progress")
      .order(:scheduled_at)
      .map { |r| build_summary(r) }
  end

  # Get completed races
  # @return [Array<Structs::RaceSummary>]
  def completed
    base_scope
      .where(status: "completed")
      .order(scheduled_at: :desc)
      .map { |r| build_summary(r) }
  end

  # Get races that should auto-start (scheduled races where scheduled_at has passed)
  # @return [Array<Structs::Race>]
  def auto_startable
    base_scope
      .where(status: "scheduled")
      .where("scheduled_at <= ?", Time.current)
      .where.not(scheduled_at: nil)
      .map { |r| build_struct(r) }
  end

  # Get races that should auto-complete (in_progress races in competitions that ended yesterday)
  # @return [Array<Structs::Race>]
  def auto_completable
    yesterday = Date.yesterday
    base_scope
      .joins(:competition)
      .where(status: "in_progress")
      .where("competitions.end_date < ?", Date.current)
      .map { |r| build_struct(r) }
  end

  protected

  # Override base scope to include associations
  def base_scope
    Race.includes(:race_type, :competition)
  end

  # Build full struct for single record operations
  # @param record [Race]
  # @return [Structs::Race]
  def build_struct(record)
    Structs::Race.new(
      id: record.id,
      competition_id: record.competition_id,
      race_type_id: record.race_type_id,
      name: record.name,
      stage_type: record.stage_type,
      stage_name: record.stage_name,
      heat_number: record.heat_number,
      scheduled_at: record.scheduled_at,
      position: record.position,
      status: record.status,
      created_at: record.created_at,
      updated_at: record.updated_at,
      race_type_name: record.race_type&.name,
      competition_name: record.competition&.name
    )
  end

  # Build summary struct for collection operations
  # @param record [Race]
  # @return [Structs::RaceSummary]
  def build_summary(record)
    Structs::RaceSummary.new(
      id: record.id,
      competition_id: record.competition_id,
      race_type_id: record.race_type_id,
      name: record.name,
      stage_type: record.stage_type,
      stage_name: record.stage_name,
      position: record.position,
      scheduled_at: record.scheduled_at,
      status: record.status,
      race_type_name: record.race_type&.name
    )
  end
end