# frozen_string_literal: true

class RacePolicy < ApplicationPolicy
  # Anyone authenticated can view races
  def index?
    true
  end

  # Anyone authenticated can view a race
  def show?
    true
  end

  # Only admins and managers can create races
  def create?
    admin? || can_manage?
  end

  # Only admins and managers can update races
  def update?
    admin? || can_manage?
  end

  # Only admins and managers can delete races
  def destroy?
    admin? || referee_manager?
  end

  # Only admins and managers can start a race
  def start?
    admin? || can_manage?
  end

  # Only admins and managers can complete a race
  def complete?
    admin? || can_manage?
  end

  # Only admins and managers can pause a race
  def pause?
    admin? || can_manage?
  end

  # Only admins and managers can cancel a race
  def cancel?
    admin? || can_manage?
  end

  class Scope < Scope
    def resolve
      # All authenticated users can see all races
      scope.all
    end
  end
end