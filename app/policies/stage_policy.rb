# frozen_string_literal: true

# Policy for Stage authorization.
#
# Performance patterns applied:
# - Memoization: Inherited from ApplicationPolicy for all role checks
# - No database queries: All checks use cached role comparisons
# - Simple boolean logic: Avoid redundant conditionals
#
class StagePolicy < ApplicationPolicy
  # Anyone authenticated can view stages
  def index?
    true
  end

  # Anyone authenticated can view a stage
  def show?
    true
  end

  # Only managers can create stages
  def create?
    can_manage?
  end

  # Only managers can update stages
  def update?
    can_manage?
  end

  # Only admins and referee managers can delete stages
  # More restrictive than general management
  def destroy?
    admin? || referee_manager?
  end

  # Only managers can reorder stages
  def reorder?
    can_manage?
  end

  # Only managers can manage races within a stage
  def manage_races?
    can_manage?
  end

  class Scope < Scope
    # All authenticated users can see all stages
    # No filtering needed - stages are part of competition structure
    def resolve
      scope.all
    end
  end
end
