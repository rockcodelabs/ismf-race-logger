# frozen_string_literal: true

# Policy for RaceParticipation authorization
#
# Determines who can create, update, and delete race participations.
# Only admins and VAR operators can manage race participations.
#
class RaceParticipationPolicy < ApplicationPolicy
  # Only admins and VAR operators can destroy participations
  def destroy?
    user.admin? || user.var_operator?
  end

  # Only admins and VAR operators can create participations
  def create?
    user.admin? || user.var_operator?
  end

  # Only admins and VAR operators can update participations
  def update?
    user.admin? || user.var_operator?
  end

  # Only admins and VAR operators can view participations list
  def index?
    user.admin? || user.var_operator?
  end

  # Only admins and VAR operators can copy participations from another race
  def copy?
    user.admin? || user.var_operator?
  end
end