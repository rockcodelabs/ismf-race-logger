# frozen_string_literal: true

# BaseBroadcaster - Base class for all Turbo Stream broadcasters
#
# Broadcasters handle real-time Turbo Stream broadcasts. They:
# - Wrap structs in Parts before rendering
# - Know nothing about business logic (just delivery)
# - Are registered in the DI container
# - Can be mocked in tests
#
# Example:
#   class IncidentBroadcaster < BaseBroadcaster
#     def created(incident)
#       broadcast_prepend(
#         stream_name(incident.race_id),
#         target: "incidents",
#         partial: "incidents/incident",
#         struct: incident,
#         as: :incident
#       )
#     end
#   end
#
class BaseBroadcaster
  include Import["parts.factory"]

  private

  # Access the parts factory (injected as `parts_factory` by dry-auto_inject)
  def parts_factory
    @parts_factory ||= send(:"parts.factory")
  end

  # Wrap a struct in its part for rendering
  def wrap(struct)
    parts_factory.wrap(struct)
  end

  # Wrap multiple structs
  def wrap_many(structs)
    parts_factory.wrap_many(structs)
  end

  # Broadcast a Turbo Stream action
  def broadcast_to(stream, action:, target:, partial:, locals:)
    Turbo::StreamsChannel.broadcast_action_to(
      stream,
      action: action,
      target: target,
      partial: partial,
      locals: locals
    )
  end

  # Broadcast append with automatic part wrapping
  def broadcast_append(stream, target:, partial:, struct:, as:)
    part = wrap(struct)
    broadcast_to(
      stream,
      action: :append,
      target: target,
      partial: partial,
      locals: { as => part }
    )
  end

  # Broadcast prepend with automatic part wrapping
  def broadcast_prepend(stream, target:, partial:, struct:, as:)
    part = wrap(struct)
    broadcast_to(
      stream,
      action: :prepend,
      target: target,
      partial: partial,
      locals: { as => part }
    )
  end

  # Broadcast replace with automatic part wrapping
  def broadcast_replace(stream, target:, partial:, struct:, as:)
    part = wrap(struct)
    broadcast_to(
      stream,
      action: :replace,
      target: target,
      partial: partial,
      locals: { as => part }
    )
  end

  # Broadcast update with automatic part wrapping
  def broadcast_update(stream, target:, partial:, struct:, as:)
    part = wrap(struct)
    broadcast_to(
      stream,
      action: :update,
      target: target,
      partial: partial,
      locals: { as => part }
    )
  end

  # Broadcast remove (no part needed)
  def broadcast_remove(stream, target:)
    Turbo::StreamsChannel.broadcast_action_to(
      stream,
      action: :remove,
      target: target
    )
  end
end
