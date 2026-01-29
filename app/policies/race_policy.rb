# frozen_string_literal: true

# RacePolicy - Authorization rules for race management
#
# Permissions:
# - Admins: Full access (create, read, update, delete)
# - VAR Operators: Full access (create, read, update, delete)
# - Referees: Read-only access
# - Others: No access
#
# Business Rules:
# - Cannot edit completed races
# - Can always delete races (as per requirements)
#
class RacePolicy < ApplicationPolicy
  # List races within a competition
  # @return [Boolean]
  def index?
    admin? || var_operator? || referee? || can_manage?
  end

  # View race details
  # @return [Boolean]
  def show?
    admin? || var_operator? || referee? || can_manage?
  end

  # Create new race
  # @return [Boolean]
  def create?
    admin? || var_operator?
  end

  # Same as create
  def new?
    create?
  end

  # Update race
  # Cannot edit completed races
  # @return [Boolean]
  def update?
    return false unless admin? || var_operator?
    return false if record.respond_to?(:completed?) && record.completed?
    true
  end

  # Same as update
  def edit?
    update?
  end

  # Delete race
  # Admins and VAR operators can delete anytime (as per requirements)
  # @return [Boolean]
  def destroy?
    admin? || var_operator?
  end

  # Scope for listing races
  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin? || var_operator? || referee? || can_manage?
        scope.all
      else
        scope.none
      end
    end
  end
end