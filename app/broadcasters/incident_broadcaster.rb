# frozen_string_literal: true

# IncidentBroadcaster - Real-time Turbo Stream broadcasts for incidents
#
# Handles broadcasting incident changes to all connected clients watching a race.
# Wraps structs in Parts before rendering to ensure consistent presentation.
#
# Example:
#   broadcaster = AppContainer["broadcasters.incident"]
#   broadcaster.created(incident_struct)   # Prepends new incident to list
#   broadcaster.updated(incident_struct)   # Replaces incident in place
#   broadcaster.deleted(incident_struct)   # Removes incident from DOM
#
class IncidentBroadcaster < BaseBroadcaster
  # Broadcast when a new incident is created
  # Prepends to the incidents list for the race
  def created(incident)
    broadcast_prepend(
      stream_name(incident.race_id),
      target: "incidents",
      partial: "incidents/incident",
      struct: incident,
      as: :incident
    )
  end

  # Broadcast when an incident is updated
  # Replaces the existing incident card in place
  def updated(incident)
    broadcast_replace(
      stream_name(incident.race_id),
      target: dom_id(incident),
      partial: "incidents/incident",
      struct: incident,
      as: :incident
    )
  end

  # Broadcast when an incident is deleted
  # Removes the incident from the DOM
  def deleted(incident)
    broadcast_remove(
      stream_name(incident.race_id),
      target: dom_id(incident)
    )
  end

  # Broadcast a status change (uses update for smoother transition)
  def status_changed(incident)
    broadcast_update(
      stream_name(incident.race_id),
      target: dom_id(incident),
      partial: "incidents/incident",
      struct: incident,
      as: :incident
    )
  end

  private

  # Stream name for race-specific incident updates
  # Clients subscribe with: turbo_stream_from "race_123_incidents"
  def stream_name(race_id)
    "race_#{race_id}_incidents"
  end

  # DOM ID for targeting specific incidents
  def dom_id(incident)
    "incident_#{incident.id}"
  end
end
