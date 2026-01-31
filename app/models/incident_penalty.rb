# frozen_string_literal: true

# IncidentPenalty - Join table for incidents and penalties
#
# Represents the many-to-many relationship between incidents and penalties.
# An incident can have multiple penalties attached (e.g., C1 + C3).
# Each penalty can only be attached once per incident (enforced by unique index).
#
# Business logic lives in:
# - Operations: app/operations/incidents/attach_penalties.rb
#
class IncidentPenalty < ApplicationRecord
  belongs_to :incident
  belongs_to :penalty
end
