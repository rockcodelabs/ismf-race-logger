# frozen_string_literal: true

# Repository for Penalty persistence operations
#
# Penalties are reference data (ISMF official penalty rules by category A-F)
#
# Usage:
#   repo = AppContainer["repos.penalty"]
#   repo.all                    # => [Structs::PenaltySummary, ...]
#   repo.find(1)                # => Structs::Penalty or nil
#   repo.by_category("A")       # => [Structs::PenaltySummary, ...]
#   repo.find_by_number("A.1")  # => Structs::Penalty or nil
#
class PenaltyRepo < DB::Repo
  # Configure the repo
  self.record_class = Penalty

  # Declare which custom methods return single vs. collection
  returns_one :find, :find!, :find_by, :find_by_number
  returns_many :all, :by_category

  # --- Single Record Methods ---

  # Find penalty by ID
  # @param id [Integer]
  # @return [Structs::Penalty, nil]
  def find(id)
    record = Penalty.find_by(id: id)
    record ? build_struct(record) : nil
  end

  # Find penalty by ID (raises if not found)
  # @param id [Integer]
  # @return [Structs::Penalty]
  # @raise [ActiveRecord::RecordNotFound]
  def find!(id)
    record = Penalty.find(id)
    build_struct(record)
  end

  # Find penalty by attributes
  # @param attrs [Hash]
  # @return [Structs::Penalty, nil]
  def find_by(attrs)
    record = Penalty.find_by(attrs)
    record ? build_struct(record) : nil
  end

  # Find penalty by penalty number (e.g., "A.1", "B.2")
  # @param number [String]
  # @return [Structs::Penalty, nil]
  def find_by_number(number)
    find_by(penalty_number: number)
  end

  # --- Collection Methods ---

  # Get all penalties ordered by category and penalty number
  # @return [Array<Structs::PenaltySummary>]
  def all
    Penalty.order(:category, :penalty_number).map { |r| build_summary(r) }
  end

  # Get penalties by category
  # @param category [String] Category letter (A-F)
  # @return [Array<Structs::PenaltySummary>]
  def by_category(category)
    Penalty.where(category: category).order(:penalty_number).map { |r| build_summary(r) }
  end

  protected

  # Build full struct for single record operations
  # @param record [Penalty]
  # @return [Structs::Penalty]
  def build_struct(record)
    Structs::Penalty.new(
      id: record.id,
      category: record.category,
      category_title: record.category_title,
      category_description: record.category_description,
      penalty_number: record.penalty_number,
      name: record.name,
      team_individual: record.team_individual,
      vertical: record.vertical,
      sprint_relay: record.sprint_relay,
      notes: record.notes,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  # Build summary struct for collection operations
  # @param record [Penalty]
  # @return [Structs::PenaltySummary]
  def build_summary(record)
    Structs::PenaltySummary.new(
      id: record.id,
      category: record.category,
      category_title: record.category_title,
      penalty_number: record.penalty_number,
      name: record.name,
      team_individual: record.team_individual,
      vertical: record.vertical,
      sprint_relay: record.sprint_relay
    )
  end
end