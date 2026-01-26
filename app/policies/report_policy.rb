# frozen_string_literal: true

# Policy for Report authorization.
#
# Performance patterns applied:
# - In-memory checks: Use record.user_id directly, avoid association queries
# - Memoization: Cache ownership and status checks
# - No N+1: Ownership uses ID comparison, not loading user association
#
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
    can_report?
  end

  # Users can update their own reports if draft or submitted; managers can update any
  def update?
    return true if can_manage?
    return false unless owns_record?

    # Can only update if the report is in draft or submitted status
    record_editable?
  end

  # Users can delete their own draft reports; managers can delete any
  def destroy?
    return true if can_manage?
    return false unless owns_record?

    record_draft?
  end

  # Users can submit their own draft reports
  def submit?
    return false unless owns_record?

    record_draft?
  end

  # Users can attach video to their own reports
  def attach_video?
    return true if can_manage?

    owns_record?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if can_manage?
        # Jury president and referee manager see all reports
        scope.all
      elsif can_report?
        # Referees and VAR operators see all reports
        scope.all
      else
        # Everyone else (broadcast viewers, etc.) sees nothing
        scope.none
      end
    end
  end

  private

  # In-memory ownership check using ID comparison
  # Avoids loading the user association - just compares integers
  # Memoized to avoid repeated checks in the same request
  def owns_record?
    return @owns_record if defined?(@owns_record)

    @owns_record = user && record &&
      record.respond_to?(:user_id) &&
      record.user_id == user.id
  end

  # In-memory draft status check
  # Uses respond_to? for safety with mocks/doubles in tests
  def record_draft?
    return @record_draft if defined?(@record_draft)

    @record_draft = if record.respond_to?(:draft?)
      record.draft?
    elsif record.respond_to?(:status)
      record.status == "draft"
    else
      false
    end
  end

  # In-memory check if record can be edited (draft or submitted)
  def record_editable?
    return @record_editable if defined?(@record_editable)

    @record_editable = if record.respond_to?(:draft?) && record.respond_to?(:submitted?)
      record.draft? || record.submitted?
    elsif record.respond_to?(:status)
      record.status.in?(%w[draft submitted])
    else
      false
    end
  end
end