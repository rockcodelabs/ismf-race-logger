# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  # Anyone authenticated can view reports (scoped by role)
  def index?
    true
  end

  # Anyone authenticated can view a report
  def show?
    true
  end

  # Referees, VAR operators, and managers can create reports
  def create?
    referee? || var_operator? || admin? || can_manage?
  end

  # Users can update their own reports if draft or submitted; admins can update any
  def update?
    return true if admin?
    return true if can_manage?
    return false unless owns_record?

    # Can only update if the report is in draft or submitted status
    record.respond_to?(:draft?) && (record.draft? || record.submitted?)
  end

  # Users can delete their own draft reports; admins and managers can delete any
  def destroy?
    return true if admin?
    return true if can_manage?
    return false unless owns_record?

    record.respond_to?(:draft?) && record.draft?
  end

  # Users can submit their own draft reports
  def submit?
    return false unless owns_record?

    record.respond_to?(:draft?) && record.draft?
  end

  # Users can attach video to their own reports
  def attach_video?
    return true if admin?

    owns_record?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if jury_president? || referee_manager?
        # Full access to all reports
        scope.all
      elsif user.referee? || var_operator?
        # Referees and VAR operators can see all reports
        scope.all
      elsif broadcast_viewer?
        # Broadcast viewers cannot see reports
        scope.none
      else
        scope.none
      end
    end
  end

  private

  def owns_record?
    return false unless user && record

    record.respond_to?(:user_id) && record.user_id == user.id
  end
end