# frozen_string_literal: true

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
    referee? || var_operator? || admin? || can_manage?
  end

  # Admins can always update; referees can update only unofficial incidents
  def update?
    return true if admin?
    return true if can_manage?

    (referee? || var_operator?) && record.respond_to?(:unofficial?) && record.unofficial?
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
    apply?
  end

  # Only jury president can decline/reject an incident
  def decline?
    jury_president?
  end

  # Alias for decline - reject decision
  def reject?
    decline?
  end

  # Only jury president can mark as no action needed
  def no_action?
    jury_president?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if jury_president? || referee_manager?
        # Full access to all incidents
        scope.all
      elsif user.international_referee?
        # International referees can see all incidents
        scope.all
      elsif user.national_referee?
        # National referees can only see incidents from their country
        # This requires the incidents to be joined with race -> stage -> competition
        if user.respond_to?(:country) && user.country.present?
          scope.joins(race: { stage: :competition })
               .where(competitions: { country: user.country })
        else
          scope.all
        end
      elsif var_operator?
        # VAR operators can see all incidents
        scope.all
      elsif broadcast_viewer?
        # Broadcast viewers cannot see incidents
        scope.none
      else
        scope.none
      end
    end
  end
end