# frozen_string_literal: true

# ExpensesJustificationPolicy - Authorization rules for expenses justification management
#
# Two-tier access control:
# - Regular users: Can manage their own expense justifications
# - ISMF staff: Can view and manage all expense justifications
#
# Permissions:
# - All authenticated users: Can create and manage their own expenses
# - ISMF staff: Full access to all expenses (approve, reject, mark as paid)
#
# Business Rules:
# - Users can only edit their own expense justifications when status is "draft"
# - Users can submit their own draft expense justifications
# - ISMF staff can approve/reject submitted expense justifications
# - ISMF staff can mark approved expenses as paid
# - Users can view their own expense justifications at any status
# - ISMF staff can view all expense justifications
#
class ExpensesJustificationPolicy < ApplicationPolicy
  # List expense justifications
  # Users see their own, ISMF staff see all
  # @return [Boolean]
  def index?
    user.present?
  end

  # View expense justification details
  # Users can view their own, ISMF staff can view all
  # @return [Boolean]
  def show?
    return false unless user.present?
    
    ismf_staff? || owns_record?
  end

  # Create new expense justification
  # All authenticated users can create
  # @return [Boolean]
  def create?
    user.present?
  end

  # Same as create
  def new?
    create?
  end

  # Update expense justification
  # Users can update their own drafts only
  # ISMF staff can update any expense justification at any status
  # @return [Boolean]
  def update?
    return false unless user.present?
    
    ismf_staff? || (owns_record? && record.status == "draft")
  end

  # Same as update
  def edit?
    update?
  end

  # Delete expense justification
  # Users can delete their own drafts only
  # ISMF staff can delete any expense justification
  # @return [Boolean]
  def destroy?
    return false unless user.present?
    
    ismf_staff? || (owns_record? && record.status == "draft")
  end

  # Submit expense justification for approval
  # Users can submit their own drafts only
  # @return [Boolean]
  def submit?
    return false unless user.present?
    
    owns_record? && record.status == "draft"
  end

  # Approve expense justification
  # Only ISMF staff can approve
  # @return [Boolean]
  def approve?
    ismf_staff?
  end

  # Reject expense justification
  # Only ISMF staff can reject
  # @return [Boolean]
  def reject?
    ismf_staff?
  end

  # Mark expense justification as paid
  # Only ISMF staff can mark as paid
  # @return [Boolean]
  def mark_as_paid?
    ismf_staff?
  end

  # Scope for listing expense justifications
  class Scope < ApplicationPolicy::Scope
    def resolve
      if ismf_staff?
        # ISMF staff see all expense justifications
        scope.all
      elsif user.present?
        # Users see only their own expense justifications
        scope.where(user_id: user.id)
      else
        scope.none
      end
    end

    private

    # Check if user is ISMF staff
    def ismf_staff?
      return @ismf_staff if defined?(@ismf_staff)
      @ismf_staff = user_role_name == "ismf_staff"
    end
  end

  private

  # Check if user is ISMF staff
  def ismf_staff?
    return @ismf_staff if defined?(@ismf_staff)
    @ismf_staff = user_role_name == "ismf_staff"
  end

  # Check if user owns this expense justification
  def owns_record?
    record.user_id == user.id
  end
end