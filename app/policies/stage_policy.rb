# frozen_string_literal: true

class StagePolicy < ApplicationPolicy
  # Anyone authenticated can view stages
  def index?
    true
  end

  # Anyone authenticated can view a stage
  def show?
    true
  end

  # Only admins and managers can create stages
  def create?
    admin? || can_manage?
  end

  # Only admins and managers can update stages
  def update?
    admin? || can_manage?
  end

  # Only admins and managers can delete stages
  def destroy?
    admin? || referee_manager?
  end

  # Only admins and managers can reorder stages
  def reorder?
    admin? || can_manage?
  end

  # Only admins and managers can manage races within a stage
  def manage_races?
    admin? || can_manage?
  end

  class Scope < Scope
    def resolve
      # All authenticated users can see all stages
      scope.all
    end
  end
end