# frozen_string_literal: true

# lib/tasks/data_reset.rake
#
# Safe data reset tasks that properly handle ActiveStorage attachments.
#
# Usage:
#   bin/rails data:reset_races          # Remove all races + dependents for all competitions
#   bin/rails data:reset_competition[13] # Remove all races + dependents for one competition
#   bin/rails data:purge_stale_blobs    # Remove orphaned / pre-dating blobs
#
# WHY THIS EXISTS:
#   TRUNCATE ... CASCADE does not cascade through polymorphic associations
#   (active_storage_attachments uses record_type/record_id, not a real FK).
#   Running raw SQL to delete reports leaves orphaned blob attachment records
#   that silently re-attach to new reports that receive the same auto-incremented IDs.
#   These tasks handle deletion in the correct dependency order using ActiveRecord
#   so that has_many_attached callbacks fire and blobs are cleaned up properly.

namespace :data do
  # ---------------------------------------------------------------------------
  # reset_races — wipe all race-related data across all competitions
  # ---------------------------------------------------------------------------
  desc "Safely remove all race-related data (races, reports, incidents, teams, locations) " \
       "including ActiveStorage attachments. Competitions are preserved."
  task reset_races: :environment do
    puts "=" * 60
    puts "DATA RESET — All races (all competitions)"
    puts "=" * 60
    DataReset.new.reset_all_races
  end

  # ---------------------------------------------------------------------------
  # reset_competition[id] — wipe race data for one competition
  # ---------------------------------------------------------------------------
  desc "Safely remove all race-related data for a single competition. " \
       "Usage: bin/rails data:reset_competition[13]"
  task :reset_competition, [:competition_id] => :environment do |_t, args|
    competition_id = args[:competition_id]&.to_i

    unless competition_id&.positive?
      puts "ERROR: Provide a competition_id, e.g. bin/rails data:reset_competition[13]"
      exit 1
    end

    competition = Competition.find_by(id: competition_id)
    unless competition
      puts "ERROR: Competition #{competition_id} not found."
      exit 1
    end

    puts "=" * 60
    puts "DATA RESET — #{competition.name} (ID=#{competition.id})"
    puts "=" * 60
    DataReset.new.reset_competition(competition)
  end

  # ---------------------------------------------------------------------------
  # purge_stale_blobs — remove orphaned blobs and blobs that pre-date their report
  # ---------------------------------------------------------------------------
  desc "Purge ActiveStorage blobs that are orphaned or older than the report they are attached to."
  task purge_stale_blobs: :environment do
    puts "=" * 60
    puts "PURGE — Stale ActiveStorage blobs"
    puts "=" * 60
    DataReset.new.purge_stale_blobs
  end
end

# ---------------------------------------------------------------------------
# DataReset service object — all logic isolated here for easy console reuse
# ---------------------------------------------------------------------------
class DataReset
  def reset_all_races
    print_before_stats

    race_ids = Race.pluck(:id)
    if race_ids.empty?
      puts "\n✅ No races found — nothing to do."
      return
    end

    puts "\nDeleting data for #{race_ids.size} race(s)..."
    destroy_reports_for(race_ids)
    destroy_incidents_for(race_ids)
    destroy_race_locations_for(race_ids)
    destroy_teams_for(race_ids)
    destroy_races(race_ids)

    print_after_stats
  end

  def reset_competition(competition)
    race_ids = Race.where(competition_id: competition.id).pluck(:id)

    if race_ids.empty?
      puts "\n✅ No races found for #{competition.name} — nothing to do."
      return
    end

    puts "\nDeleting data for #{race_ids.size} race(s) in #{competition.name}..."
    destroy_reports_for(race_ids)
    destroy_incidents_for(race_ids)
    destroy_race_locations_for(race_ids)
    destroy_teams_for(race_ids)
    destroy_races(race_ids)

    print_after_stats
  end

  def purge_stale_blobs
    stale_count   = 0
    orphan_count  = 0

    # 1. Attachments pointing to records that no longer exist
    stale = ActiveStorage::Attachment
      .where(record_type: "Report")
      .where.not(record_id: Report.select(:id))

    if stale.any?
      blob_ids = stale.pluck(:blob_id).uniq
      stale.delete_all
      stale_count += stale.size

      # Purge blobs that are now fully unattached
      still_used = ActiveStorage::Attachment.where(blob_id: blob_ids).pluck(:blob_id).uniq
      orphaned   = blob_ids - still_used
      ActiveStorage::Blob.where(id: orphaned).find_each do |blob|
        puts "  Purging orphaned blob: #{blob.filename} (#{format_size(blob.byte_size)})"
        blob.purge
        orphan_count += 1
      end
    end

    # 2. Attachments where blob was created BEFORE the report (leftover from a prior reset)
    ActiveStorage::Attachment.where(record_type: "Report").includes(:blob).find_each do |att|
      report = Report.find_by(id: att.record_id)
      next unless report
      next unless att.blob&.created_at
      next unless att.blob.created_at < report.created_at

      puts "  Removing pre-dating blob: Report #{report.id} ← #{att.blob.filename} " \
           "(blob #{att.blob.created_at.strftime('%Y-%m-%d')} / report #{report.created_at.strftime('%Y-%m-%d')})"
      blob = att.blob
      att.destroy
      blob.purge unless ActiveStorage::Attachment.where(blob_id: blob.id).exists?
      stale_count += 1
    end

    if stale_count.zero?
      puts "\n✅ No stale blobs found."
    else
      puts "\n✅ Removed #{stale_count} stale attachment(s), purged #{orphan_count} blob(s)."
    end
  end

  private

  # Destroy reports (+ their ActiveStorage videos) for the given race IDs.
  # Uses destroy_all so has_many_attached :videos callbacks fire correctly.
  def destroy_reports_for(race_ids)
    reports = Report.where(race_id: race_ids)
    count   = reports.count
    return if count.zero?

    puts "  Destroying #{count} report(s) (including video attachments)..."
    # destroy_all fires has_many_attached purge callbacks
    reports.find_each(&:destroy)
    puts "    ✅ #{count} report(s) destroyed"
  end

  def destroy_incidents_for(race_ids)
    incidents = Incident.where(race_id: race_ids)
    count     = incidents.count
    return if count.zero?

    puts "  Deleting #{count} incident(s)..."
    incidents.delete_all
    puts "    ✅ Done"
  end

  def destroy_race_locations_for(race_ids)
    locations = RaceLocation.where(race_id: race_ids)
    count     = locations.count
    return if count.zero?

    puts "  Deleting #{count} race location(s)..."
    locations.delete_all
    puts "    ✅ Done"
  end

  def destroy_teams_for(race_ids)
    teams = Team.where(race_id: race_ids)
    count = teams.count
    return if count.zero?

    puts "  Deleting #{count} team(s) + participations..."
    RaceParticipation.where(race_id: race_ids).delete_all
    teams.delete_all
    puts "    ✅ Done"
  end

  def destroy_races(race_ids)
    count = race_ids.size
    puts "  Deleting #{count} race(s)..."
    Race.where(id: race_ids).delete_all
    puts "    ✅ Done"
  end

  def print_before_stats
    puts "\nBefore:"
    puts "  Races:          #{Race.count}"
    puts "  Reports:        #{Report.count}"
    puts "  Video blobs:    #{ActiveStorage::Attachment.where(record_type: 'Report').count}"
    puts "  Incidents:      #{Incident.count}"
    puts "  Teams:          #{Team.count}"
    puts "  Race locations: #{RaceLocation.count}"
    puts "  Competitions:   #{Competition.count} (preserved)"
  end

  def print_after_stats
    puts "\nAfter:"
    puts "  Races:          #{Race.count}"
    puts "  Reports:        #{Report.count}"
    puts "  Video blobs:    #{ActiveStorage::Attachment.where(record_type: 'Report').count}"
    puts "  Incidents:      #{Incident.count}"
    puts "  Teams:          #{Team.count}"
    puts "  Race locations: #{RaceLocation.count}"
    puts "  Competitions:   #{Competition.count}"
    puts "\n✅ Reset complete."
    puts "=" * 60
  end

  def format_size(bytes)
    if bytes >= 1.gigabyte
      "#{(bytes / 1.gigabyte.to_f).round(1)} GB"
    elsif bytes >= 1.megabyte
      "#{(bytes / 1.megabyte.to_f).round(1)} MB"
    else
      "#{(bytes / 1.kilobyte.to_f).round(1)} KB"
    end
  end
end