# frozen_string_literal: true

# ReportPolicy - Authorization rules for report management
#
# Reports are created by field referees to document potential rule violations.
# All authenticated users with reporting roles can manage reports.
#
# Permissions:
# - Admins: Full access
# - VAR Operators: Full access
# - Referees: Full access
# - Jury President: Full access
# - Referee Manager: Full access
# - Others: No access
#
# Business Rules:
# - All reporting roles can create, confirm, reject, and reopen reports
# - Reports are the first step in the incident workflow
#
class ReportPolicy < ApplicationPolicy
  # List reports for a race
  # @return [Boolean]
  def index?
    can_report?
  end

  # View report details
  # @return [Boolean]
  def show?
    can_report?
  end

  # Create new report
  # @return [Boolean]
  def create?
    can_report?
  end

  # Same as create
  def new?
    create?
  end

  # Confirm a pending report
  # @return [Boolean]
  def confirm?
    can_report?
  end

  # Reject a pending report
  # @return [Boolean]
  def reject?
    can_report?
  end

  # Reopen a rejected report
  # @return [Boolean]
  def reopen?
    can_report?
  end

  # Update report (general)
  # @return [Boolean]
  def update?
    can_report?
  end

  # Same as update
  def edit?
    update?
  end

  # Delete report
  # Only admins can delete reports
  # @return [Boolean]
  def destroy?
    admin?
  end

  # Scope for listing reports
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
