# frozen_string_literal: true

# Penalty model (associations only)
#
# Represents ISMF race penalties organized by categories (A-F).
# Each penalty has a category letter, title, description, penalty number,
# and race-type-specific penalty values.
#
# Categories:
# - A: General infringements not specifically cited
# - B: Equipment violations
# - C: Course and marking violations
# - D: Start and finish violations
# - E: Climbing and skiing technique
# - F: Safety and environmental violations
#
# Business logic lives in:
# - Repo: app/db/repos/penalty_repo.rb
# - Struct: app/db/structs/penalty.rb
# - Summary: app/db/structs/penalty_summary.rb
#
class Penalty < ApplicationRecord
  # No associations yet - this is reference data
end