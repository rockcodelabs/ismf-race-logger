# frozen_string_literal: true

# Policy for Race authorization.
#
# Performance patterns applied:
# - Memoization: Inherited from ApplicationPolicy for all role checks
# - No database queries: All checks use cached role comparisons
# - Simple boolean logic: Avoid complex conditionals
#
class RacePolicy < ApplicationPolicy
  # Anyone authenticated can view races
  def index?
    true
  end

  # Anyone authenticated can view a race
  def show?
    true
  end

  # Only managers can create races
  def create?
    can_manage?
  end

  # Only managers can update races
  def update?
    can_manage?
  end

  # Only admins and referee managers can delete races
  def destroy?
    admin? || referee_manager?
  end

  # Only managers can start a race
  def start?
    can_manage?
  end

  # Only managers can complete a race
  def complete?
    can_manage?
  end

  # Only managers can pause a race
  def pause?
    can_manage?
  end

  # Only managers can cancel a race
  def cancel?
    can_manage?
  end

  class Scope < Scope
    # All authenticated users can see all races
    # No filtering needed - races are public within the system
    def resolve
      scope.all
    end
  end
end
