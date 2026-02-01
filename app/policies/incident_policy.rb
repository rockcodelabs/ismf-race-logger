# frozen_string_literal: true

# IncidentPolicy - Authorization rules for incident management
#
# Incidents are created by merging confirmed reports into an official incident
# that may result in penalties.
#
# Permissions:
# - VAR Operators: Full access (create, decide, attach_penalties, reopen)
# - Referee Manager: Can view and decide incidents (no create/reopen)
# - Jury President: Can view and decide incidents (no create/reopen)
# - Referees: Read-only access (can view but not modify incidents)
# - Others: No access
#
# Business Rules:
# - Only VAR operators can merge reports into incidents (create)
# - VAR operators, referee managers, and jury presidents can decide incidents
# - Only VAR operators can attach or modify penalties
# - Only VAR operators can reopen decided incidents
#
class IncidentPolicy < ApplicationPolicy
  # List incidents
  # @return [Boolean]
  def index?
    can_report?
  end

  # View incident details
  # VAR operators, referee managers, jury presidents, and referees can view
  # @return [Boolean]
  def show?
    var_operator? || referee_manager? || jury_president? || referee?
  end

  # Create incident (merge reports)
  # Only VAR operators can merge reports into incidents
  # @return [Boolean]
  def create?
    var_operator?
  end

  # Same as create
  def new?
    create?
  end

  # Update incident (general updates)
  # VAR operators, referee managers, and jury presidents can update incidents
  # @return [Boolean]
  def update?
    var_operator? || referee_manager? || jury_president?
  end

  # Same as update
  def edit?
    update?
  end

  # Make a decision on the incident (upheld/dismissed)
  # VAR operators, referee managers, and jury presidents can decide incidents
  # @return [Boolean]
  def decide?
    var_operator? || referee_manager? || jury_president?
  end

  # Attach or modify penalties on the incident
  # Only VAR operators can attach penalties
  # @return [Boolean]
  def attach_penalties?
    var_operator?
  end

  # Reopen a decided incident for further review
  # Only VAR operators can reopen incidents
  # @return [Boolean]
  def reopen?
    var_operator?
  end

  # Delete incident
  # @return [Boolean]
  def destroy?
    admin?
  end

  private

  # Memoized check for admin or VAR operator
  # @return [Boolean]
  def admin_or_var?
    return @admin_or_var if defined?(@admin_or_var)

    @admin_or_var = admin? || var_operator?
  end

  # Scope for listing incidents
  class Scope < ApplicationPolicy::Scope
    def resolve
      if var_operator? || referee_manager? || jury_president? || referee?
        scope.all
      else
        scope.none
      end
    end
  end
end
