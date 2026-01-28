# frozen_string_literal: true

# Broadcasts real-time Turbo Stream updates for {{Resource}} changes
#
# Usage:
#   broadcaster = AppContainer["broadcasters.{{resource}}"]
#   broadcaster.created({{resource}}_struct)
#   broadcaster.updated({{resource}}_struct)
#   broadcaster.deleted({{resource}}_struct)
#
# Streams:
#   Clients subscribe via: turbo_stream_from "{{stream_name}}"
#
class {{Resource}}Broadcaster < BaseBroadcaster
  # Broadcast when a new {{resource}} is created
  # Prepends to the list so newest appears first
  def created({{resource}})
    broadcast_prepend(
      stream: stream_name({{resource}}),
      target: "{{resources}}",
      partial: "{{partial_path}}/{{resource}}",
      locals: { {{resource}}: wrap({{resource}}) }
    )
  end

  # Broadcast when a {{resource}} is updated
  # Replaces the existing element in place
  def updated({{resource}})
    broadcast_replace(
      stream: stream_name({{resource}}),
      target: wrap({{resource}}).dom_id,
      partial: "{{partial_path}}/{{resource}}",
      locals: { {{resource}}: wrap({{resource}}) }
    )
  end

  # Broadcast when a {{resource}} is deleted
  # Removes the element from the DOM
  def deleted({{resource}})
    broadcast_remove(
      stream: stream_name({{resource}}),
      target: wrap({{resource}}).dom_id
    )
  end

  private

  # Define the stream name for broadcasting
  # Customize based on scoping needs (e.g., per-race, per-user)
  def stream_name({{resource}})
    # Option 1: Global stream
    # "{{resources}}"

    # Option 2: Scoped stream (e.g., per parent resource)
    # "parent_#{{{resource}}.parent_id}_{{resources}}"

    "{{resources}}"
  end
end

# Placeholders:
#   {{Resource}}     - Singular resource name (e.g., Incident)
#   {{resource}}     - Lowercase singular (e.g., incident)
#   {{resources}}    - Lowercase plural (e.g., incidents)
#   {{stream_name}}  - Turbo stream name (e.g., race_1_incidents)
#   {{partial_path}} - Path to partial (e.g., admin/incidents)
#
# Remember to:
#   1. Register in config/initializers/container.rb:
#      register "broadcasters.{{resource}}", memoize: true do
#        {{Resource}}Broadcaster.new
#      end
#
#   2. Create the Part class (Web::Parts::{{Resource}}) for dom_id
#
#   3. Add subscription in view:
#      <%= turbo_stream_from "{{stream_name}}" %>