# frozen_string_literal: true

# Incident model (associations only)
#
# An incident is created when one or more reports are merged/confirmed.
# Incidents receive decisions (approved/rejected) and can have penalties attached.
#
# Workflow:
#   Reports (pending_review) → [Confirm/Merge] → Incident (pending) → [Decide] → (approved/rejected)
#
# Business logic lives in:
# - Operations: app/operations/incidents/
# - Repo: app/db/repos/incident_repo.rb
# - Struct: app/db/structs/incident.rb
#
class Incident < ApplicationRecord
  belongs_to :race
  belongs_to :race_location, optional: true
  belongs_to :decided_by_user, class_name: "User", optional: true

  has_many :reports, dependent: :nullify
  has_many :incident_penalties, dependent: :destroy
  has_many :penalties, through: :incident_penalties
  has_many :notes, as: :notable, dependent: :destroy
end
