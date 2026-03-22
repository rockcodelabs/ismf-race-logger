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
#   repo.visible_for_race(race_id)            # => [Structs::ReportSummary, ...] (primary only)
#   repo.visible_by_status(race_id, status)   # => [Structs::ReportSummary, ...] (primary only)
#   repo.visible_count_by_status(race_id)     # => Hash (primary only)
#   repo.for_race(race_id)                    # => [Structs::ReportSummary, ...] (all)
#   repo.pending_for_race(race_id)            # => [Structs::ReportSummary, ...]
#   repo.find(id)                             # => Structs::Report or nil
#   repo.find_by_client_uuid(uuid)            # => Structs::Report or nil
#   repo.available_for_merge(race_id, ...)    # => [Structs::ReportSummary, ...] (for merge UI)
#   repo.confirmed_without_incident(race_id)  # => [Structs::ReportSummary, ...] (legacy)
#   repo.counts_for_races(race_ids)           # => Hash { race_id => count } (single query)
#
class ReportRepo < DB::Repo
  self.record_class = Report
  self.struct_class = Structs::Report
  self.summary_class = Structs::ReportSummary

  returns_one :find, :find!, :find_by_client_uuid
  returns_many :for_race, :pending_for_race, :confirmed_for_race, :for_incident,
               :confirmed_without_incident, :pending_without_incident, :by_bib, :recent,
               :for_competition_races

  # Get total report counts for multiple races in a single DB query.
  # Returns a Hash of { race_id (Integer) => count (Integer) }.
  # Races with no reports are not included (use .to_i on the result to default to 0).
  #
  # @param race_ids [Array<Integer>]
  # @return [Hash{Integer => Integer}] e.g., { 1 => 3, 5 => 12 }
  def counts_for_races(race_ids)
    return {} if race_ids.blank?

    Report.where(race_id: race_ids).group(:race_id).count
  end

  # Get all reports for multiple races, ordered by most recent first.
  # Used for competition-level reports feed on phone view.
  #
  # @param race_ids [Array<Integer>]
  # @return [Array<Structs::ReportSummary>]
  def for_competition_races(race_ids)
    return [] if race_ids.blank?

    Report
      .where(race_id: race_ids)
      .includes(:race_location, :user,
                { race_participation: { athlete: [], team: [:athlete_1, :athlete_2] } },
                { videos_attachments: :blob })
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Find report by client_uuid (for idempotency/offline sync)
  # @param uuid [String]
  # @return [Structs::Report, nil]
  def find_by_client_uuid(uuid)
    record = Report.find_by(client_uuid: uuid)
    record ? build_struct(record) : nil
  end

  # ─── Unified Index (primary reports only) ─────────────────────────────────

  # Get all visible reports for a race — excludes secondary (merged) reports.
  # Secondary = reports linked to an incident where another report in that
  # incident has a lower ID (i.e., they were merged in, not the primary).
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def visible_for_race(race_id)
    primary_ids = primary_incident_report_ids(race_id)

    scope = base_scope
      .where(race_id: race_id)
      .includes(incident: [:reports, { incident_penalties: :penalty }])
      .order(created_at: :desc)

    scope = apply_primary_filter(scope, primary_ids)
    scope.map { |record| build_summary(record) }
  end

  # Get visible reports filtered by status — excludes secondary reports.
  # @param race_id [Integer]
  # @param status [String] One of: pending_review, confirmed, rejected
  # @return [Array<Structs::ReportSummary>]
  def visible_by_status(race_id, status)
    primary_ids = primary_incident_report_ids(race_id)

    scope = base_scope
      .where(race_id: race_id, status: status)
      .includes(incident: [:reports, { incident_penalties: :penalty }])
      .order(created_at: :desc)

    scope = apply_primary_filter(scope, primary_ids)
    scope.map { |record| build_summary(record) }
  end

  # Count visible (primary) reports by status for a race.
  # @param race_id [Integer]
  # @return [Hash] e.g., { "pending_review" => 4, "confirmed" => 2, "rejected" => 1 }
  def visible_count_by_status(race_id)
    primary_ids = primary_incident_report_ids(race_id)

    scope = Report.where(race_id: race_id)
    scope = apply_primary_filter(scope, primary_ids)
    scope.group(:status).count
  end

  # Get reports available to be merged with another report.
  # Returns primary/standalone non-rejected reports excluding specified IDs.
  # @param race_id [Integer]
  # @param exclude_ids [Array<Integer>] report IDs to exclude (current report + already merged)
  # @return [Array<Structs::ReportSummary>]
  def available_for_merge(race_id, exclude_ids: [])
    primary_ids = primary_incident_report_ids(race_id)

    scope = base_scope
      .where(race_id: race_id)
      .where.not(status: "rejected")
      .includes(incident: [:reports, { incident_penalties: :penalty }])
      .order(created_at: :desc)

    scope = apply_primary_filter(scope, primary_ids)
    scope = scope.where.not(id: exclude_ids) if exclude_ids.any?
    scope.map { |record| build_summary(record) }
  end

  # ─── All-records queries (no secondary filtering) ─────────────────────────

  # Get all reports for a race, ordered by most recent first
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def for_race(race_id)
    Report
      .where(race_id: race_id)
      .includes(:race_location, :user,
                incident: [:reports, { incident_penalties: :penalty }],
                race_participation: :athlete, videos_attachments: :blob)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get pending_review reports for a race (for touch display queue)
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def pending_for_race(race_id)
    Report
      .where(race_id: race_id, status: "pending_review")
      .includes(:race_location, :user,
                incident: [:reports, { incident_penalties: :penalty }],
                race_participation: :athlete, videos_attachments: :blob)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get confirmed reports for a race
  # @param race_id [Integer]
  # @return [Array<Structs::ReportSummary>]
  def confirmed_for_race(race_id)
    Report
      .where(race_id: race_id, status: "confirmed")
      .includes(:race_location, :user,
                incident: [:reports, { incident_penalties: :penalty }],
                race_participation: :athlete, videos_attachments: :blob)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Get confirmed reports NOT yet linked to an incident (legacy / backward compat)
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
      .includes(:race_location, :user,
                incident: [:reports, { incident_penalties: :penalty }],
                race_participation: :athlete, videos_attachments: :blob)
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

  # Get reports by status for a race (all reports, not filtered for primary)
  # Use visible_by_status for the unified index.
  # @param race_id [Integer]
  # @param status [String] One of: pending_review, confirmed, rejected
  # @return [Array<Structs::ReportSummary>]
  def by_status(race_id, status)
    Report
      .where(race_id: race_id, status: status)
      .includes(:race_location, :user,
                incident: [:reports, { incident_penalties: :penalty }],
                race_participation: :athlete)
      .order(created_at: :desc)
      .map { |record| build_summary(record) }
  end

  # Count reports by status for a race (all reports, not filtered for primary)
  # Use visible_count_by_status for the unified index.
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
    Report.includes(
      :race_location, :user,
      { race_participation: { athlete: [], team: [:athlete_1, :athlete_2] } },
      { videos_attachments: :blob }
    )
  end

  def build_struct(record)
    record = record.is_a?(Report) ? record : Report.includes(:race_location, :user, race_participation: { athlete: [], team: [:athlete_1, :athlete_2] }, videos_attachments: :blob).find(record)

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
      athlete_gender: build_athlete_gender(record),
      user_name: record.user&.display_name,
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

    # Count other reports merged into the same incident
    merged_count = if incident
      # incident.reports is eagerly loaded when using visible_* or for_incident queries
      count = incident.reports.respond_to?(:loaded?) && incident.reports.loaded? ?
        incident.reports.size :
        Report.where(incident_id: incident.id).count
      [count - 1, 0].max
    else
      0
    end

    # Extract penalty details from the incident (for display in the index row)
    incident_penalties = if incident && incident.association(:incident_penalties).loaded?
      incident.incident_penalties.map do |ip|
        { number: ip.penalty.penalty_number, name: ip.penalty.name }
      end
    else
      []
    end

    Structs::ReportSummary.new(
      id: record.id,
      race_id: record.race_id,
      incident_id: record.incident_id,
      incident_name: incident_name,
      incident_status: incident_struct&.status,
      incident_has_decision: incident_struct ? !incident_struct.pending? : false,
      incident_penalties: incident_penalties,
      bib_number: record.bib_number,
      athlete_position: record.athlete_position,
      race_location_id: record.race_location_id,
      race_location_name: record.race_location&.name,
      athlete_name: build_athlete_name(record),
      athlete_country: build_athlete_country(record),
      athlete_gender: build_athlete_gender(record),
      user_name: record.user&.display_name,
      status: record.status,
      created_at: record.created_at,
      videos_count: record.videos.count,
      merged_reports_count: merged_count
    )
  end

  private

  # ─── Primary-report filtering helpers ─────────────────────────────────────

  # Returns the IDs of the "primary" report per incident (lowest ID per incident_id).
  # Only primary reports are shown in the unified index.
  # @param race_id [Integer]
  # @return [Array<Integer>]
  def primary_incident_report_ids(race_id)
    Report
      .where(race_id: race_id)
      .where.not(incident_id: nil)
      .group(:incident_id)
      .minimum(:id)
      .values
  end

  # Applies the primary-only filter to an ActiveRecord scope.
  # Shows standalone reports (no incident) plus the primary report per incident.
  # @param scope [ActiveRecord::Relation]
  # @param primary_ids [Array<Integer>]
  # @return [ActiveRecord::Relation]
  def apply_primary_filter(scope, primary_ids)
    if primary_ids.empty?
      scope
    else
      scope.where("reports.incident_id IS NULL OR reports.id IN (?)", primary_ids)
    end
  end

  # ─── Athlete attribute builders ────────────────────────────────────────────

  def build_athlete_name(record)
    # For relay teams with athlete_position == 2, show the female (athlete_2)
    if record.athlete_position == 2
      female = record.race_participation&.team&.athlete_2
      return "#{female.first_name} #{female.last_name}" if female
    end

    athlete = record.race_participation&.athlete
    return nil unless athlete

    "#{athlete.first_name} #{athlete.last_name}"
  end

  def build_athlete_country(record)
    # For relay teams with athlete_position == 2, use female athlete's country
    if record.athlete_position == 2
      female = record.race_participation&.team&.athlete_2
      return female.country if female
    end

    record.race_participation&.athlete&.country
  end

  def build_athlete_gender(record)
    # For relay teams with athlete_position == 2, the athlete is female
    if record.athlete_position == 2
      female = record.race_participation&.team&.athlete_2
      return female&.gender || "F"
    end

    record.race_participation&.athlete&.gender
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