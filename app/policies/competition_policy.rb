# frozen_string_literal: true

class CompetitionPolicy < ApplicationPolicy
  # Anyone authenticated can view competitions
  def index?
    true
  end

  # Anyone authenticated can view a competition
  def show?
    true
  end

  # Only admins and managers can create competitions
  def create?
    admin? || can_manage?
  end

  # Only admins and managers can update competitions
  def update?
    admin? || can_manage?
  end

  # Only referee managers can delete competitions
  def destroy?
    referee_manager?
  end

  # Only admins and managers can duplicate competitions
  def duplicate?
    admin? || can_manage?
  end

  # Only admins and managers can archive competitions
  def archive?
    admin? || can_manage?
  end

  # Only admins and managers can create competitions from templates
  def create_from_template?
    admin? || can_manage?
  end

  # Only admins and managers can manage stages within a competition
  def manage_stages?
    admin? || can_manage?
  end

  class Scope < Scope
    def resolve
      # All authenticated users can see all competitions
      scope.all
    end
  end
end