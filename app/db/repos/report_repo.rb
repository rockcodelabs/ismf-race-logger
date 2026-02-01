# frozen_string_literal: true

# ReportRepo
#
# Repository for reports (quick captures of potential incidents during races).
# Provides query methods for retrieving and managing reports.
#
# Returns:
# - Single records: Structs::Report (full struct)
# - Collections: Structs::ReportSummary (for lists) or Structs::Report (for detail views)
#
# Usage:
#   repo = AppContainer["repos.report"]
#   repo.for_race(race_id)                    # => [Structs::ReportSummary, ...]
#   repo.pending_for_race(race_id)            # => [Structs::ReportSummary, ...]
#   repo.find(id)                             # => Structs::Report or nil
#   repo.find_by_client_uuid(uuid)            # => Structs::Report or nil
#   repo.confirmed_without_incident(race_id)  # => [Structs::ReportSummary, ...] (for merge UI)
#
class ReportRepo < DB::Repo
  self.record_class = Report
  self.struct_class = Structs::Report
  self.summary_class = Structs::ReportSummary

  returns_one :find, :find!, :find_by_client_uuid
  returns_many :for_race, :pending_for_race, :confirmed_for_race, :for_incident,
               :confirmed_without_incident, :pending_without_incident, :by_bib, :recent

  # Find report by client_uuid (for idempotency/offline sync)
  # @param uuid [String]
  # @return [Structs::Report, nil]
  def find_by_client_uuid(uuid)
    record = Report.find_by(client_uuid: uuid)
    record ? build_struct(record) : nil
  end

  # Get all reports for a race, ordered by most recent first
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def for_race(race_id)
    Report
      .where(race_id: race_id)
      .includes(:race_location, :incident, :user, race_participation: :athlete, videos_attachments: :blob)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get pending_review reports for a race (for touch display queue)
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def pending_for_race(race_id)
    Report
      .where(race_id: race_id, status: "pending_review")
      .includes(:race_location, :user, race_participation: :athlete, videos_attachments: :blob)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get confirmed reports for a race
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def confirmed_for_race(race_id)
    Report
      .where(race_id: race_id, status: "confirmed")
      .includes(:race_location, :user, race_participation: :athlete, videos_attachments: :blob)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get confirmed reports NOT yet linked to an incident (for merge UI)
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def confirmed_without_incident(race_id)
    Report
      .where(race_id: race_id, status: "confirmed", incident_id: nil)
      .includes(:race_location, :user, race_participation: :athlete)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get pending_review reports NOT yet linked to an incident (for VAR dashboard)
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def pending_without_incident(race_id)
    Report
      .where(race_id: race_id, status: "pending_review", incident_id: nil)
      .includes(:race_location, :user, race_participation: :athlete)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get all reports for a specific incident
  # @param incident_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def for_incident(incident_id)
    Report
      .where(incident_id: incident_id)
      .includes(:race_location, :user, race_participation: :athlete)
      .order(created_at: :asc)
      .map { |record| build_summary(record) }
  end

  # Get reports by bib number for a race
  # @param race_id [Integer]
  # @param bib_number [Integer]
  # @return [Array<Structs::ReportSummary>]
  def by_bib(race_id, bib_number)
    Report
      .where(race_id: race_id, bib_number: bib_number)
      .includes(:race_location, :user, race_participation: :athlete)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get recent reports across all races (for admin dashboard)
  # @param limit [Integer]
  # @return [Array<Structs::ReportSummary>]
  def recent(limit = 20)
    Report
      .includes(:race_location, :user, race_participation: :athlete)
      .order(created_at: :desc)
      .limit(limit)
      .map { |record| build_summary(record) }
  end

  # Get reports by status for a race
  # @param race_id [Integer]
  # @param status [String] One of: pending_review, confirmed, rejected
  # @return [Array<Structs::ReportSummary>]
  def by_status(race_id, status)
    Report
      .where(race_id: race_id, status: status)
      .includes(:race_location, :user, race_participation: :athlete)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Count reports by status for a race
  # @param race_id [Integer]
  # @return [Hash] e.g., { "pending_review" => 5, "confirmed" => 3, "rejected" => 1 }
  def count_by_status(race_id)
    Report
      .where(race_id: race_id)
      .group(:status)
      .count
  end

  protected

  def base_scope
    Report.includes(:race_location, :user, race_participation: :athlete, videos_attachments: :blob)
  end

  def build_struct(record)
    record = record.is_a?(Report) ? record : Report.includes(:race_location, :user, race_participation: :athlete, videos_attachments: :blob).find(record)

    Structs::Report.new(
      id: record.id,
      client_uuid: record.client_uuid,
      race_id: record.race_id,
      incident_id: record.incident_id,
      user_id: record.user_id,
      race_location_id: record.race_location_id,
      race_participation_id: record.race_participation_id,
      bib_number: record.bib_number,
      athlete_position: record.athlete_position,
      description: record.description,
      status: record.status,
      created_at: record.created_at,
      updated_at: record.updated_at,
      videos: record.videos.attached? ? record.videos.blobs.to_a : [],
      race_location_name: record.race_location&.name,
      athlete_name: build_athlete_name(record),
      athlete_country: build_athlete_country(record),
      user_name: record.user&.display_name
    )
  end

  def build_summary(record)
    incident = record.incident
    incident_struct = incident ? build_incident_struct(incident) : nil
    incident_name = if incident
      incident.custom_name.presence || "Incident ##{incident.id}"
    else
      nil
    end
    
    Structs::ReportSummary.new(
      id: record.id,
      race_id: record.race_id,
      incident_id: record.incident_id,
      incident_name: incident_name,
      incident_status: incident_struct&.status,
      incident_has_decision: incident_struct ? !incident_struct.pending? : false,
      bib_number: record.bib_number,
      athlete_position: record.athlete_position,
      race_location_id: record.race_location_id,
      race_location_name: record.race_location&.name,
      athlete_name: build_athlete_name(record),
      athlete_country: build_athlete_country(record),
      user_name: record.user&.display_name,
      status: record.status,
      created_at: record.created_at,
      videos_count: record.videos.count
    )
  end

  private

  def build_athlete_name(record)
    athlete = record.race_participation&.athlete
    return nil unless athlete

    "#{athlete.first_name} #{athlete.last_name}"
  end

  def build_athlete_country(record)
    record.race_participation&.athlete&.country
  end

  def build_incident_struct(incident_record)
    Structs::Incident.new(
      id: incident_record.id,
      client_uuid: incident_record.client_uuid,
      race_id: incident_record.race_id,
      race_location_id: incident_record.race_location_id,
      status: incident_record.status,
      custom_name: incident_record.custom_name,
      description: incident_record.description,
      decided_by_user_id: incident_record.decided_by_user_id,
      decided_at: incident_record.decided_at,
      created_at: incident_record.created_at,
      updated_at: incident_record.updated_at,
      race_location_name: nil,
      decided_by_user_name: nil,
      reports_count: nil,
      penalties_count: nil
    )
  end
end
