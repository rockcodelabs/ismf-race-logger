# frozen_string_literal: true

# CompetitionRepo - Repository for Competition data access (Hanami-style)
#
# Inherits from DB::Repo which provides:
# - find, find!, first, last, find_by (single record → Structs::Competition)
# - all, where, many (collections → Structs::CompetitionSummary)
# - count, exists?, pluck (aggregates)
# - create, update, delete (CRUD)
#
# This repo only defines:
# - Custom query methods (upcoming, ongoing, past, search)
# - base_scope override (eager loading, default ordering)
# - build_struct / build_summary (mapping record → struct)
#
# Example:
#   repo = CompetitionRepo.new
#
#   competition = repo.find(1)              # => Structs::Competition (inherited)
#   competitions = repo.upcoming            # => [Structs::CompetitionSummary, ...]
#   competitions = repo.search("Verbier")   # => [Structs::CompetitionSummary, ...]
#
class CompetitionRepo < DB::Repo
  # Configure the repo
  self.record_class = Competition
  self.struct_class = Structs::Competition
  self.summary_class = Structs::CompetitionSummary

  # Document return types for reference
  returns_one :find_by_name
  returns_many :upcoming, :ongoing, :past, :search, :by_country, :by_city, :by_date_range

  # ===========================================================================
  # CUSTOM SINGLE RECORD METHODS
  # ===========================================================================

  # Find competition by exact name
  def find_by_name(name)
    record = base_scope.find_by(name: name)
    to_struct(record)
  end

  # ===========================================================================
  # CUSTOM COLLECTION METHODS
  # ===========================================================================

  # Return upcoming competitions (start_date in the future)
  def upcoming
    base_scope
      .where("start_date > ?", Date.current)
      .reorder(start_date: :asc)
      .map { |record| to_summary(record) }
  end

  # Return ongoing competitions (currently happening)
  def ongoing
    base_scope
      .where("start_date <= ? AND end_date >= ?", Date.current, Date.current)
      .order(start_date: :desc)
      .map { |record| to_summary(record) }
  end

  # Return past competitions (end_date in the past)
  def past
    base_scope
      .where("end_date < ?", Date.current)
      .order(start_date: :desc)
      .map { |record| to_summary(record) }
  end

  # Search competitions by name, city, or place (case-insensitive)
  def search(query)
    return [] if query.blank?

    pattern = "%#{query}%"
    base_scope
      .where("name ILIKE ? OR city ILIKE ? OR place ILIKE ?", pattern, pattern, pattern)
      .order(start_date: :desc)
      .map { |record| to_summary(record) }
  end

  # Return competitions by country code
  def by_country(country_code)
    base_scope
      .where(country: country_code)
      .order(start_date: :desc)
      .map { |record| to_summary(record) }
  end

  # Return competitions by city (case-insensitive)
  def by_city(city)
    base_scope
      .where("city ILIKE ?", city)
      .order(start_date: :desc)
      .map { |record| to_summary(record) }
  end

  # Return competitions within a date range
  def by_date_range(start_date, end_date)
    base_scope
      .where("start_date >= ? AND end_date <= ?", start_date, end_date)
      .order(:start_date)
      .map { |record| to_summary(record) }
  end

  # Return all competitions with filtering and sorting
  # Options:
  #   status: :upcoming, :ongoing, :past (default: all)
  #   sort: :recent, :oldest, :name (default: :recent)
  def filtered(status: nil, sort: :recent)
    scope = base_scope

    # Apply status filter
    case status&.to_sym
    when :upcoming
      scope = scope.where("start_date > ?", Date.current)
    when :ongoing
      scope = scope.where("start_date <= ? AND end_date >= ?", Date.current, Date.current)
    when :past
      scope = scope.where("end_date < ?", Date.current)
    end

    # Apply sorting
    scope = case sort&.to_sym
    when :oldest
      scope.order(:start_date)
    when :name
      scope.order(:name)
    else # :recent
      scope.order(start_date: :desc)
    end

    scope.map { |record| to_summary(record) }
  end

  # ===========================================================================
  # CUSTOM AGGREGATE METHODS
  # ===========================================================================

  # Check if competition name exists
  def name_exists?(name, exclude_id: nil)
    scope = Competition.where(name: name)
    scope = scope.where.not(id: exclude_id) if exclude_id
    scope.exists?
  end

  # Count competitions by status
  def count_by_status
    {
      upcoming: Competition.where("start_date > ?", Date.current).count,
      ongoing: Competition.where("start_date <= ? AND end_date >= ?", Date.current, Date.current).count,
      past: Competition.where("end_date < ?", Date.current).count
    }
  end

  # ===========================================================================
  # PROTECTED: Mapping methods
  # ===========================================================================

  protected

  # Default scope with eager loading and ordering
  # This prevents N+1 queries and provides consistent ordering
  def base_scope
    Competition.order(start_date: :desc)
  end

  # Build a full struct from a Competition record
  def build_struct(record)
    Structs::Competition.new(
      id: record.id,
      name: record.name,
      city: record.city,
      place: record.place,
      country: record.country,
      description: record.description.to_s,
      start_date: record.start_date,
      end_date: record.end_date,
      webpage_url: record.webpage_url,
      logo_url: record.logo.attached? ? Rails.application.routes.url_helpers.rails_blob_path(record.logo, only_path: true) : nil,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  # Build a summary struct from a Competition record
  def build_summary(record)
    Structs::CompetitionSummary.new(
      id: record.id,
      name: record.name,
      city: record.city,
      place: record.place,
      country: record.country,
      start_date: record.start_date,
      end_date: record.end_date,
      created_at: record.created_at
    )
  end
end