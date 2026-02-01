# frozen_string_literal: true

# IncidentRepo
#
# Repository for incidents (confirmed reports merged into actionable items).
# Provides query methods for retrieving and managing incidents.
#
# Returns:
# - Single records: Structs::Incident (full struct)
# - Collections: Structs::IncidentSummary (for lists)
#
# Usage:
#   repo = AppContainer["repos.incident"]
#   repo.for_race(race_id)                # => [Structs::IncidentSummary, ...]
#   repo.pending_for_race(race_id)        # => [Structs::IncidentSummary, ...]
#   repo.find(id)                         # => Structs::Incident or nil
#   repo.find_by_client_uuid(uuid)        # => Structs::Incident or nil
#
class IncidentRepo < DB::Repo
  self.record_class = Incident
  self.struct_class = Structs::Incident
  self.summary_class = Structs::IncidentSummary

  returns_one :find, :find!, :find_by_client_uuid
  returns_many :for_race, :pending_for_race, :decided_for_race, :recent

  # Find incident by client_uuid (for idempotency/offline sync)
  # @param uuid [String]
  # @return [Structs::Incident, nil]
  def find_by_client_uuid(uuid)
    record = Incident.find_by(client_uuid: uuid)
    record ? build_struct(record) : nil
  end

  # Get all incidents for a race, ordered by most recent first
  # @param race_id [Integer]
  # @return [Array<Structs::IncidentSummary>]
  def for_race(race_id)
    Incident
      .where(race_id: race_id)
      .includes(:race_location, { incident_penalties: :penalty }, reports: [:user, { race_participation: :athlete }])
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get pending incidents for a race (awaiting decision)
  # @param race_id [Integer]
  # @return [Array<Structs::IncidentSummary>]
  def pending_for_race(race_id)
    Incident
      .where(race_id: race_id, status: "pending")
      .includes(:race_location, { incident_penalties: :penalty }, reports: [:user, { race_participation: :athlete }])
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get decided incidents for a race (approved or rejected)
  # @param race_id [Integer]
  # @return [Array<Structs::IncidentSummary>]
  def decided_for_race(race_id)
    Incident
      .where(race_id: race_id, status: %w[approved rejected])
      .includes(:race_location, { incident_penalties: :penalty }, reports: [:user, { race_participation: :athlete }])
      .order(decided_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get approved incidents for a race
  # @param race_id [Integer]
  # @return [Array<Structs::IncidentSummary>]
  def approved_for_race(race_id)
    Incident
      .where(race_id: race_id, status: "approved")
      .includes(:race_location, { incident_penalties: :penalty }, reports: [:user, { race_participation: :athlete }])
      .order(decided_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get rejected incidents for a race
  # @param race_id [Integer]
  # @return [Array<Structs::IncidentSummary>]
  def rejected_for_race(race_id)
    Incident
      .where(race_id: race_id, status: "rejected")
      .includes(:race_location, { incident_penalties: :penalty }, reports: [:user, { race_participation: :athlete }])
      .order(decided_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get incidents by status for a race
  # @param race_id [Integer]
  # @param status [String] One of: pending, approved, rejected
  # @return [Array<Structs::IncidentSummary>]
  def by_status(race_id, status)
    Incident
      .where(race_id: race_id, status: status)
      .includes(:race_location, { incident_penalties: :penalty }, reports: [:user, { race_participation: :athlete }])
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get recent incidents across all races (for admin dashboard)
  # @param limit [Integer]
  # @return [Array<Structs::IncidentSummary>]
  def recent(limit = 20)
    Incident
      .includes(:race_location, :reports, :incident_penalties)
      .order(created_at: :desc)
      .limit(limit)
      .map { |record| build_summary(record) }
  end

  # Count incidents by status for a race
  # @param race_id [Integer]
  # @return [Hash] e.g., { "pending" => 5, "approved" => 3, "rejected" => 1 }
  def count_by_status(race_id)
    Incident
      .where(race_id: race_id)
      .group(:status)
      .count
  end

  # Get incidents with their associated reports (for detail views)
  # @param incident_id [Integer]
  # @return [Structs::Incident, nil]
  def find_with_reports(incident_id)
    record = Incident
      .includes(:race_location, :decided_by_user, :reports, :incident_penalties, :penalties)
      .find_by(id: incident_id)

    record ? build_struct(record) : nil
  end

  protected

  def base_scope
    Incident.includes(:race_location, :decided_by_user, :reports, :incident_penalties)
  end

  def build_struct(record)
    record = load_full_record(record) unless record.is_a?(Incident) && record.association(:race_location).loaded?

    Structs::Incident.new(
      id: record.id,
      client_uuid: record.client_uuid,
      race_id: record.race_id,
      race_location_id: record.race_location_id,
      status: record.status,
      custom_name: record.custom_name,
      description: record.description,
      decided_by_user_id: record.decided_by_user_id,
      decided_at: record.decided_at,
      created_at: record.created_at,
      updated_at: record.updated_at,
      race_location_name: record.race_location&.name,
      decided_by_user_name: record.decided_by_user&.display_name,
      reports_count: record.reports.size,
      penalties_count: record.incident_penalties.size
    )
  end

  def build_summary(record)
    bib_numbers = record.reports.map(&:bib_number).uniq.sort
    reporter_names = record.reports.map { |r| r.user&.display_name }.compact
    penalty_details = record.incident_penalties.map do |ip|
      { number: ip.penalty.penalty_number, name: ip.penalty.name }
    end
    
    # Collect unique athletes from all reports
    athletes = record.reports.map do |r|
      athlete = r.race_participation&.athlete
      next unless athlete
      
      {
        first_name: athlete.first_name,
        last_name: athlete.last_name,
        country: athlete.country
      }
    end.compact.uniq

    Structs::IncidentSummary.new(
      id: record.id,
      race_id: record.race_id,
      race_location_id: record.race_location_id,
      race_location_name: record.race_location&.name,
      custom_name: record.custom_name,
      status: record.status,
      reports_count: record.reports.size,
      penalties_count: record.incident_penalties.size,
      penalty_details: penalty_details,
      bib_numbers: bib_numbers,
      reporter_names: reporter_names,
      athletes: athletes,
      created_at: record.created_at
    )
  end

  private

  def load_full_record(record_or_id)
    id = record_or_id.is_a?(Incident) ? record_or_id.id : record_or_id
    Incident
      .includes(:race_location, :decided_by_user, :reports, :incident_penalties)
      .find(id)
  end
end
