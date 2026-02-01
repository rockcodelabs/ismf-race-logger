# frozen_string_literal: true

# ReportBroadcaster - Real-time Turbo Stream broadcasts for reports
#
# Handles broadcasting report changes to all connected clients watching a race.
# Wraps structs in Parts before rendering to ensure consistent presentation.
#
# Example:
#   broadcaster = AppContainer["broadcasters.report"]
#   broadcaster.created(report_struct, race_id)   # Prepends new report to list
#   broadcaster.confirmed(report_struct, race_id) # Updates counters
#   broadcaster.rejected(report_struct, race_id)  # Updates counters
#   broadcaster.reopened(report_struct, race_id)  # Updates counters
#
class ReportBroadcaster < BaseBroadcaster
  # Broadcast when a new report is created
  # Prepends to the pending reports queue and updates counter
  def created(report, race_id)
    race = Race.find(race_id)
    part = wrap(report)
    
    # Broadcast card format for touch displays (pending queue div)
    Turbo::StreamsChannel.broadcast_prepend_to(
      stream_name(race_id),
      target: "pending-reports-queue",
      partial: "admin/races/reports/report_card",
      locals: { report: part, race: race }
    )
    
    # Broadcast table row format for desktop (reports table tbody)
    Turbo::StreamsChannel.broadcast_prepend_to(
      stream_name(race_id),
      target: "reports-table-body",
      partial: "admin/races/reports/report_row",
      locals: { report: part, race: race }
    )
    
    # Update counters
    update_counters(race_id)
    
    # Broadcast flash message to all devices
    broadcast_flash_notice(race_id, "Report ##{report.bib_number} created.")
  end

  # Broadcast when a report is confirmed
  # Removes from pending queue and updates counters
  def confirmed(report, race_id)
    Turbo::StreamsChannel.broadcast_remove_to(
      stream_name(race_id),
      target: dom_id(report)
    )
    
    update_counters(race_id)
    
    # Broadcast flash message to all devices
    broadcast_flash_notice(race_id, "Report ##{report.bib_number} confirmed.")
  end

  # Broadcast when a report is rejected
  # Removes from pending queue and updates counters
  def rejected(report, race_id)
    Turbo::StreamsChannel.broadcast_remove_to(
      stream_name(race_id),
      target: dom_id(report)
    )
    
    update_counters(race_id)
    
    # Broadcast flash message to all devices
    broadcast_flash_notice(race_id, "Report ##{report.bib_number} rejected.")
  end

  # Broadcast when a report is reopened
  # Prepends back to pending queue and updates counters
  def reopened(report, race_id)
    race = Race.find(race_id)
    part = wrap(report)
    
    # Broadcast card format for touch displays (pending queue div)
    Turbo::StreamsChannel.broadcast_prepend_to(
      stream_name(race_id),
      target: "pending-reports-queue",
      partial: "admin/races/reports/report_card",
      locals: { report: part, race: race }
    )
    
    # Broadcast table row format for desktop (reports table tbody)
    Turbo::StreamsChannel.broadcast_prepend_to(
      stream_name(race_id),
      target: "reports-table-body",
      partial: "admin/races/reports/report_row",
      locals: { report: part, race: race }
    )
    
    update_counters(race_id)
    
    # Broadcast flash message to all devices
    broadcast_flash_notice(race_id, "Report ##{report.bib_number} reopened.")
  end

  # Broadcast when a report is deleted
  # Removes from all views and updates counters
  def deleted(report, race_id)
    Turbo::StreamsChannel.broadcast_remove_to(
      stream_name(race_id),
      target: dom_id(report)
    )
    
    update_counters(race_id)
    
    # Broadcast flash message to all devices
    broadcast_flash_notice(race_id, "Report ##{report.bib_number} deleted.")
  end

  # Broadcast when multiple reports are deleted (bulk deletion)
  # More efficient than calling deleted() for each report individually
  def bulk_deleted(reports, race_id)
    reports.each do |report|
      Turbo::StreamsChannel.broadcast_remove_to(
        stream_name(race_id),
        target: dom_id(report)
      )
    end
    
    # Update counters once after all deletions
    update_counters(race_id)
    
    # Broadcast single flash message for bulk operation
    count = reports.size
    broadcast_flash_notice(race_id, "Deleted #{count} report#{count == 1 ? '' : 's'} successfully.")
  end

  # Broadcast when videos are attached to a report
  # Replaces the report row with updated HTML showing video thumbnails
  def videos_attached(report)
    race = Race.find(report.race_id)
    part = wrap(report)
    
    # Broadcast updated table row for desktop (reports table tbody)
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(report.race_id),
      target: dom_id(report),
      partial: "admin/races/reports/report_row",
      locals: { report: part, race: race }
    )
    
    # Broadcast flash message to all devices
    count = report.videos.count
    broadcast_flash_notice(report.race_id, "#{count} video#{count == 1 ? '' : 's'} added to report ##{report.bib_number}.")
  end

  private

  # Stream name for race-specific report updates
  # Clients subscribe with: turbo_stream_from "race_123_reports"
  def stream_name(race_id)
    "race_#{race_id}_reports"
  end

  # DOM ID for targeting specific reports
  def dom_id(report)
    "report_#{report.id}"
  end

  # Update status counters for all connected clients
  def update_counters(race_id)
    report_repo = AppContainer["repos.report"]
    status_counts = report_repo.count_by_status(race_id)
    
    Turbo::StreamsChannel.broadcast_action_to(
      stream_name(race_id),
      action: :update,
      target: "pending-count-badge",
      html: status_counts["pending_review"] || 0
    )
    
    Turbo::StreamsChannel.broadcast_action_to(
      stream_name(race_id),
      action: :update,
      target: "confirmed-count",
      html: status_counts["confirmed"] || 0
    )
    
    Turbo::StreamsChannel.broadcast_action_to(
      stream_name(race_id),
      action: :update,
      target: "rejected-count",
      html: status_counts["rejected"] || 0
    )
  end

  # Broadcast flash notice message to all connected clients
  def broadcast_flash_notice(race_id, message)
    Turbo::StreamsChannel.broadcast_append_to(
      stream_name(race_id),
      target: "flash-messages",
      partial: "shared/flash",
      locals: { type: "notice", message: message }
    )
  end

  # Broadcast flash alert message to all connected clients
  def broadcast_flash_alert(race_id, message)
    Turbo::StreamsChannel.broadcast_append_to(
      stream_name(race_id),
      target: "flash-messages",
      partial: "shared/flash",
      locals: { type: "alert", message: message }
    )
  end
end