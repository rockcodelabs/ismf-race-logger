# frozen_string_literal: true

class RaceTypePolicy < ApplicationPolicy
  # Anyone authenticated can view race types
  def index?
    true
  end

  # Anyone authenticated can view a race type
  def show?
    true
  end

  # Only admins and managers can create race types
  def create?
    admin? || can_manage?
  end

  # Only admins and managers can update race types
  def update?
    admin? || can_manage?
  end

  # Only referee managers can delete race types
  def destroy?
    referee_manager?
  end

  # Only admins and managers can manage location templates for race types
  def manage_templates?
    admin? || can_manage?
  end

  # Only admins and managers can add location templates
  def add_location_template?
    admin? || can_manage?
  end

  # Only admins and managers can remove location templates
  def remove_location_template?
    admin? || can_manage?
  end

  class Scope < Scope
    def resolve
      # All authenticated users can see all race types
      scope.all
    end
  end
end