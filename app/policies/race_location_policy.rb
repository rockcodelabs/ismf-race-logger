# frozen_string_literal: true

# RaceLocationPolicy - Authorization rules for race location management
#
# Permissions:
# - Admins: Full access (create, read, update, delete, reorder)
# - VAR Operators: Full access
# - Referees: Read-only access
# - Others: No access
#
# Business Rules:
# - Cannot edit locations for completed races
# - Can always view locations (for reporting interface)
#
class RaceLocationPolicy < ApplicationPolicy
  # List locations for a race
  # @return [Boolean]
  def index?
    admin? || var_operator? || referee?
  end

  # View location details
  # @return [Boolean]
  def show?
    admin? || var_operator? || referee?
  end

  # Create new location
  # @return [Boolean]
  def create?
    admin? || var_operator?
  end

  # Same as create
  def new?
    create?
  end

  # Update location
  # Cannot edit locations for completed races
  # @return [Boolean]
  def update?
    return false unless admin? || var_operator?
    # If record has race association, check if race is completed
    return false if record.respond_to?(:race) && record.race&.status == "completed"
    true
  end

  # Same as update
  def edit?
    update?
  end

  # Delete location
  # Admins and VAR operators can delete (except for completed races)
  # @return [Boolean]
  def destroy?
    return false unless admin? || var_operator?
    return false if record.respond_to?(:race) && record.race&.status == "completed"
    true
  end

  # Reorder locations
  # @return [Boolean]
  def reorder?
    admin? || var_operator?
  end

  # Scope for listing locations
  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin? || var_operator? || referee?
        scope.all
      else
        scope.none
      end
    end
  end
end