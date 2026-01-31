# frozen_string_literal: true

# Policy for Competition authorization.
#
# Performance patterns applied:
# - Memoization: Inherited from ApplicationPolicy for all role checks
# - No database queries: All checks use cached role comparisons
# - Simple boolean logic: Avoid redundant conditionals
#
class CompetitionPolicy < ApplicationPolicy
  # Anyone authenticated can view competitions list
  def index?
    true
  end

  # Anyone authenticated can view a competition
  def show?
    true
  end

  # Admins and managers can create competitions
  def create?
    admin? || can_manage?
  end

  # Admins and managers can update competitions
  def update?
    admin? || can_manage?
  end

  # Only admins and referee managers can delete competitions
  def destroy?
    admin? || referee_manager?
  end

  # Admins and managers can duplicate competitions
  def duplicate?
    admin? || can_manage?
  end

  # Admins and managers can archive competitions
  def archive?
    admin? || can_manage?
  end

  # Admins and managers can create competitions from templates
  def create_from_template?
    admin? || can_manage?
  end

  # Admins and managers can manage stages within a competition
  def manage_stages?
    admin? || can_manage?
  end

  class Scope < Scope
    # All authenticated users can see all competitions
    # No filtering needed - competitions are public within the system
    def resolve
      scope.all
    end
  end
end
