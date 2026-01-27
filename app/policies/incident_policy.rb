# frozen_string_literal: true

# Policy for Incident authorization.
#
# Performance patterns applied:
# - In-memory checks: Use record attributes directly, avoid extra queries
# - Efficient scopes: Use JOINs for filtering, not find_each loops
# - Memoization: Inherited from ApplicationPolicy for role checks
#
class IncidentPolicy < ApplicationPolicy
  # Anyone authenticated can view incidents (scoped by role)
  def index?
    true
  end

  # Anyone authenticated can view an incident
  def show?
    true
  end

  # Referees, VAR operators, and managers can create incidents
  def create?
    can_report?
  end

  # Admins can always update; referees/operators can update only unofficial incidents
  def update?
    return true if can_manage?

    can_report? && record_unofficial?
  end

  # Only admins and managers can delete incidents
  def destroy?
    admin? || referee_manager?
  end

  # Only jury president can officialize an incident
  def officialize?
    jury_president?
  end

  # Only jury president can apply a penalty
  def apply?
    jury_president?
  end

  # Alias for apply - apply penalty decision
  def apply_penalty?
    jury_president?
  end

  # Only jury president can decline/reject an incident
  def decline?
    jury_president?
  end

  # Alias for decline - reject decision
  def reject?
    jury_president?
  end

  # Only jury president can mark as no action needed
  def no_action?
    jury_president?
  end

  private

  # In-memory check for unofficial status - avoids extra query
  # Uses respond_to? for safety when record is a mock/double
  def record_unofficial?
    return false unless record

    if record.respond_to?(:unofficial?)
      record.unofficial?
    elsif record.respond_to?(:status)
      # Fallback: check status attribute directly (in-memory)
      record.status == "unofficial"
    else
      false
    end
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if can_manage?
        # Jury president and referee manager see all
        scope.all
      elsif international_referee?
        # International referees see all incidents
        scope.all
      elsif user_role_name == "national_referee"
        # National referees see only incidents from their country
        # Use efficient JOIN instead of N+1 queries
        filter_by_user_country
      elsif var_operator?
        # VAR operators see all incidents
        scope.all
      elsif broadcast_viewer?
        # Broadcast viewers cannot see incidents
        scope.none
      else
        scope.none
      end
    end

    private

    # Efficient JOIN-based filtering for national referees
    # Single query instead of loading all and filtering in Ruby
    def filter_by_user_country
      user_country = user.respond_to?(:country) ? user.country : nil

      if user_country.present?
        # Use JOINs to filter by country in a single query
        scope.joins(race: { stage: :competition })
             .where(competitions: { country: user_country })
      else
        # No country set - fall back to showing all
        # This is a business decision: restrict or allow?
        scope.all
      end
    end
  end
end
