# frozen_string_literal: true

class RulePolicy < ApplicationPolicy
  # Anyone authenticated can view rules
  def index?
    true
  end

  # Anyone authenticated can view a rule
  def show?
    true
  end

  # Only admins and managers can create rules
  def create?
    admin? || can_manage?
  end

  # Only admins and managers can update rules
  def update?
    admin? || can_manage?
  end

  # Only referee managers can delete rules
  def destroy?
    referee_manager?
  end

  # Only admins and managers can import rules
  def import?
    admin? || can_manage?
  end

  # Only admins and managers can export rules
  def export?
    admin? || can_manage?
  end

  class Scope < Scope
    def resolve
      # All authenticated users can see all rules
      scope.all
    end
  end
end