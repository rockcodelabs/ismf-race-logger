# frozen_string_literal: true

# IncidentPolicy - Authorization rules for incident management
#
# Incidents are created by merging confirmed reports into an official incident
# that may result in penalties.
#
# Permissions:
# - Admins: Full access (create, decide, attach_penalties, reopen)
# - VAR Operators: Full access (create, decide, attach_penalties, reopen)
# - Referees: Read-only access (can view but not modify incidents)
# - Others: No access
#
# Business Rules:
# - Only admin/VAR can merge reports into incidents
# - Only admin/VAR can make decisions on incidents
# - Only admin/VAR can attach or modify penalties
# - Only admin/VAR can reopen decided incidents
#
class IncidentPolicy < ApplicationPolicy
  # List incidents
  # @return [Boolean]
  def index?
    can_report?
  end

  # View incident details
  # @return [Boolean]
  def show?
    can_report?
  end

  # Create incident (merge reports)
  # Only admin and VAR operators can merge reports into incidents
  # @return [Boolean]
  def create?
    admin_or_var?
  end

  # Same as create
  def new?
    create?
  end

  # Update incident (general updates)
  # @return [Boolean]
  def update?
    admin_or_var?
  end

  # Same as update
  def edit?
    update?
  end

  # Make a decision on the incident (upheld/dismissed)
  # @return [Boolean]
  def decide?
    admin_or_var?
  end

  # Attach or modify penalties on the incident
  # @return [Boolean]
  def attach_penalties?
    admin_or_var?
  end

  # Reopen a decided incident for further review
  # @return [Boolean]
  def reopen?
    admin_or_var?
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
      if can_report?
        scope.all
      else
        scope.none
      end
    end
  end
end
