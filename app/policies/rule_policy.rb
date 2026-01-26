# frozen_string_literal: true

# Policy for Rule authorization.
#
# Performance patterns applied:
# - Memoization: Inherited from ApplicationPolicy for all role checks
# - No database queries: All checks use cached role comparisons
# - Simple boolean logic: Avoid redundant conditionals
#
class RulePolicy < ApplicationPolicy
  # Anyone authenticated can view rules
  def index?
    true
  end

  # Anyone authenticated can view a rule
  def show?
    true
  end

  # Only managers can create rules
  def create?
    can_manage?
  end

  # Only managers can update rules
  def update?
    can_manage?
  end

  # Only referee managers can delete rules
  # More restrictive than general management
  def destroy?
    referee_manager?
  end

  # Only managers can import rules
  def import?
    can_manage?
  end

  # Only managers can export rules
  def export?
    can_manage?
  end

  class Scope < Scope
    # All authenticated users can see all rules
    # No filtering needed - rules are reference data
    def resolve
      scope.all
    end
  end
end