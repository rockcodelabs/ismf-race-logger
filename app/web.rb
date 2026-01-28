# frozen_string_literal: true

# Web Layer - HTTP interface and presentation logic
#
# This layer contains:
# - Controllers (thin adapters) - app/web/controllers/
# - Parts (presentation decorators) - app/web/parts/
# - Templates (ERB views) - app/web/templates/
#
# Delegates to Operations for business logic and uses Repos for data access.
# Depends on Operations, DB (repos/structs), and Models layers.
#
# Key patterns:
# - Controllers call operations and wrap structs in parts
# - Parts add view-specific presentation logic to structs
# - Templates use parts for all presentation (no inline logic)
#
module Web
end
