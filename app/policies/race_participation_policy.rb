# frozen_string_literal: true

# Policy for RaceParticipation authorization
#
# Determines who can create, update, and delete race participations.
# Only admins and VAR operators can manage race participations.
#
class RaceParticipationPolicy < ApplicationPolicy
  # Only VAR operators can destroy participations
  def destroy?
    var_operator?
  end

  # Only VAR operators can create participations
  def create?
    var_operator?
  end

  # Only VAR operators can update participations
  def update?
    var_operator?
  end

  # Only VAR operators can view participations list
  def index?
    var_operator?
  end

  # Only VAR operators can copy participations from another race
  def copy?
    var_operator?
  end
end