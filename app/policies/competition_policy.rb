# frozen_string_literal: true

# Policy for Competition authorization.
#
# Performance patterns applied:
# - Memoization: Inherited from ApplicationPolicy for all role checks
# - No database queries: All checks use cached role comparisons
# - Simple boolean logic: Avoid redundant conditionals
#
class CompetitionPolicy < ApplicationPolicy
  # Anyone authenticated can view competitions
  def index?
    true
  end

  # Anyone authenticated can view a competition
  def show?
    true
  end

  # Only managers can create competitions
  def create?
    can_manage?
  end

  # Only managers can update competitions
  def update?
    can_manage?
  end

  # Only referee managers can delete competitions
  # More restrictive than general management
  def destroy?
    referee_manager?
  end

  # Only managers can duplicate competitions
  def duplicate?
    can_manage?
  end

  # Only managers can archive competitions
  def archive?
    can_manage?
  end

  # Only managers can create competitions from templates
  def create_from_template?
    can_manage?
  end

  # Only managers can manage stages within a competition
  def manage_stages?
    can_manage?
  end

  class Scope < Scope
    # All authenticated users can see all competitions
    # No filtering needed - competitions are public within the system
    def resolve
      scope.all
    end
  end
end