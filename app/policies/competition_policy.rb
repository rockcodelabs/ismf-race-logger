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

  # Only VAR operators can create competitions
  def create?
    var_operator?
  end

  # Only VAR operators can update competitions
  def update?
    var_operator?
  end

  # Only VAR operators can delete competitions
  def destroy?
    var_operator?
  end

  # Only VAR operators can duplicate competitions
  def duplicate?
    var_operator?
  end

  # Only VAR operators can archive competitions
  def archive?
    var_operator?
  end

  # Only VAR operators can create competitions from templates
  def create_from_template?
    var_operator?
  end

  # Only VAR operators can manage stages within a competition
  def manage_stages?
    var_operator?
  end

  class Scope < Scope
    # All authenticated users can see all competitions
    # No filtering needed - competitions are public within the system
    def resolve
      scope.all
    end
  end
end
