# frozen_string_literal: true

# Policy for RaceType authorization.
#
# Performance patterns applied:
# - Memoization: Inherited from ApplicationPolicy for all role checks
# - No database queries: All checks use cached role comparisons
# - Simple boolean logic: Avoid redundant conditionals
#
class RaceTypePolicy < ApplicationPolicy
  # Anyone authenticated can view race types
  def index?
    true
  end

  # Anyone authenticated can view a race type
  def show?
    true
  end

  # Only managers can create race types
  def create?
    can_manage?
  end

  # Only managers can update race types
  def update?
    can_manage?
  end

  # Only referee managers can delete race types
  # More restrictive than general management
  def destroy?
    referee_manager?
  end

  # Only managers can manage location templates for race types
  def manage_templates?
    can_manage?
  end

  # Only managers can add location templates
  def add_location_template?
    can_manage?
  end

  # Only managers can remove location templates
  def remove_location_template?
    can_manage?
  end

  class Scope < Scope
    # All authenticated users can see all race types
    # No filtering needed - race types are reference data
    def resolve
      scope.all
    end
  end
end
