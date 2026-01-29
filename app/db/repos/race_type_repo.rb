# frozen_string_literal: true

# Repository for RaceType persistence operations
#
# RaceTypes are reference data (predefined: Individual, Team, Sprint, Vertical, Mixed Relay)
#
# Usage:
#   repo = AppContainer["repos.race_type"]
#   repo.all                    # => [Structs::RaceTypeSummary, ...]
#   repo.find(1)                # => Structs::RaceType or nil
#   repo.find_by_name("Sprint") # => Structs::RaceType or nil
#
class RaceTypeRepo < DB::Repo
  # Configure the repo
  self.record_class = RaceType

  # Declare which custom methods return single vs. collection
  returns_one :find, :find!, :find_by, :find_by_name
  returns_many :all

  # --- Single Record Methods ---

  # Find race type by ID
  # @param id [Integer]
  # @return [Structs::RaceType, nil]
  def find(id)
    record = RaceType.find_by(id: id)
    record ? build_struct(record) : nil
  end

  # Find race type by ID (raises if not found)
  # @param id [Integer]
  # @return [Structs::RaceType]
  # @raise [ActiveRecord::RecordNotFound]
  def find!(id)
    record = RaceType.find(id)
    build_struct(record)
  end

  # Find race type by attributes
  # @param attrs [Hash]
  # @return [Structs::RaceType, nil]
  def find_by(attrs)
    record = RaceType.find_by(attrs)
    record ? build_struct(record) : nil
  end

  # Find race type by name
  # @param name [String]
  # @return [Structs::RaceType, nil]
  def find_by_name(name)
    find_by(name: name)
  end

  # --- Collection Methods ---

  # Get all race types (for dropdown options)
  # @return [Array<Structs::RaceTypeSummary>]
  def all
    RaceType.order(:name).map { |r| build_summary(r) }
  end

  protected

  # Build full struct for single record operations
  # @param record [RaceType]
  # @return [Structs::RaceType]
  def build_struct(record)
    Structs::RaceType.new(
      id: record.id,
      name: record.name,
      description: record.description,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  # Build summary struct for collection operations
  # @param record [RaceType]
  # @return [Structs::RaceTypeSummary]
  def build_summary(record)
    Structs::RaceTypeSummary.new(
      id: record.id,
      name: record.name,
      description: record.description
    )
  end
end