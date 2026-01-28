# frozen_string_literal: true

# RaceRepo - Repository for Race data access (Hanami-style)
#
# This is the public interface for race persistence.
# All query logic lives here, NOT in the Race model.
# Returns structs (immutable data objects), not ActiveRecord models.
#
# TODO: Implement fully when Race model is migrated
#
# Example:
#   repo = RaceRepo.new
#
#   race = repo.find(1)              # => RaceStruct or nil
#   races = repo.all                 # => [RaceSummary, ...]
#   races = repo.active              # => [RaceSummary, ...]
#
class RaceRepo < DB::Repo
  # Note: Race model needs to be created first
  # self.record_class = Race

  # Document return types for reference
  returns_one :find, :find!, :first, :last, :find_by, :create, :update
  returns_many :all, :where, :many, :active, :upcoming, :completed

  # ===========================================================================
  # SINGLE RECORD METHODS
  # ===========================================================================

  # TODO: Implement when Race model exists

  # ===========================================================================
  # COLLECTION METHODS
  # ===========================================================================

  # Return all active races
  def active
    # TODO: base_scope.where(status: "active").map { |record| to_summary(record) }
    []
  end

  # Return all upcoming races
  def upcoming
    # TODO: base_scope.where(status: "upcoming").map { |record| to_summary(record) }
    []
  end

  # Return all completed races
  def completed
    # TODO: base_scope.where(status: "completed").map { |record| to_summary(record) }
    []
  end

  # ===========================================================================
  # PROTECTED: Mapping methods
  # ===========================================================================

  protected

  # Default scope with ordering
  def base_scope
    # TODO: Race.order(start_time: :desc)
    raise NotImplementedError, "Race model not yet created"
  end

  # Build a full struct from a Race record
  def build_struct(record)
    # TODO: Implement when Race struct is created
    raise NotImplementedError, "#{self.class} must implement #build_struct"
  end

  # Build a summary struct from a Race record
  def build_summary(record)
    # TODO: Implement when Race summary struct is created
    raise NotImplementedError, "#{self.class} must implement #build_summary"
  end
end