# frozen_string_literal: true

# Policy for RaceLocation authorization.
#
# Performance patterns applied:
# - In-memory checks: Use record attributes directly, avoid extra queries
# - Memoization: Cache template and referee status checks
# - Efficient scopes: Use database scopes when available, not Ruby filtering
#
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
  # VAR operators and managers see all; referees see referee-designated locations
  def show_camera_stream?
    return true if can_manage?
    return true if var_operator?

    # Referees can view camera streams for referee-designated locations
    referee? && record_is_referee_location?
  end

  # Only managers can create race locations
  def create?
    can_manage?
  end

  # Only managers can update race locations
  def update?
    can_manage?
  end

  # Only admins/referee managers can delete, and only if not from template
  def destroy?
    return false unless admin? || referee_manager?

    # Cannot delete locations created from template
    !record_from_template?
  end

  # Only managers can add cameras to locations
  def manage_camera?
    can_manage?
  end

  private

  # In-memory check for template origin
  # Memoized to avoid repeated checks
  def record_from_template?
    return @record_from_template if defined?(@record_from_template)

    @record_from_template = if record.respond_to?(:from_template?)
      record.from_template?
    elsif record.respond_to?(:from_template)
      # Check boolean attribute directly
      record.from_template == true
    else
      false
    end
  end

  # In-memory check for referee-designated location
  # Memoized to avoid repeated checks
  def record_is_referee_location?
    return @record_is_referee_location if defined?(@record_is_referee_location)

    @record_is_referee_location = if record.respond_to?(:referee?)
      record.referee?
    elsif record.respond_to?(:location_type)
      # Check location_type attribute directly
      record.location_type.to_s.include?("referee")
    else
      false
    end
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if broadcast_viewer?
        # Broadcast viewers can only see locations with cameras
        # Use database scope if available, otherwise return all
        filter_camera_locations
      else
        # All other authenticated users can see all locations
        scope.all
      end
    end

    private

    # Use database scope for camera filtering (efficient)
    # Falls back to all if scope not defined (for flexibility)
    def filter_camera_locations
      if scope.respond_to?(:with_camera)
        scope.with_camera
      else
        # Fallback: return all if scope not defined
        # This allows the policy to work before the model scope exists
        scope.all
      end
    end
  end
end