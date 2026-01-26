# frozen_string_literal: true

class RaceLocationPolicy < ApplicationPolicy
  # Anyone authenticated can view race locations
  def index?
    true
  end

  # Anyone authenticated can view a race location
  def show?
    true
  end

  # Camera stream access is role-based
  def show_camera_stream?
    return true if admin?
    return true if can_manage?
    return true if var_operator?

    # Referees can view camera streams for referee-designated locations
    referee? && record.respond_to?(:referee?) && record.referee?
  end

  # Only admins and managers can create race locations
  def create?
    admin? || can_manage?
  end

  # Only admins and managers can update race locations
  def update?
    admin? || can_manage?
  end

  # Only admins can delete non-template locations
  def destroy?
    return false unless admin? || referee_manager?

    # Cannot delete locations created from template
    !record.respond_to?(:from_template?) || !record.from_template?
  end

  # Only admins and managers can add cameras to locations
  def manage_camera?
    admin? || can_manage?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if broadcast_viewer?
        # Broadcast viewers can only see locations with cameras
        if scope.respond_to?(:with_camera)
          scope.with_camera
        else
          scope.all
        end
      else
        # All other authenticated users can see all locations
        scope.all
      end
    end
  end
end