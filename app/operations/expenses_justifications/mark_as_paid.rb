# frozen_string_literal: true

module Operations
  module ExpensesJustifications
    # Marks an expenses justification as paid
    #
    # Changes paid flag from false to true and sets paid_at timestamp.
    # Only ISMF staff can mark as paid.
    # Expense must be approved before it can be marked as paid.
    #
    # @example
    #   result = Operations::ExpensesJustifications::MarkAsPaid.new.call(
    #     id: 1,
    #     current_user: ismf_staff_user
    #   )
    #
    class MarkAsPaid
      include Dry::Monads[:result]

      def initialize(expenses_justification_repo: AppContainer["repos.expenses_justification"])
        @expenses_justification_repo = expenses_justification_repo
      end

      # @param id [Integer] Expense justification ID
      # @param current_user [User] Current user (must be ISMF staff)
      # @return [Dry::Monads::Result] Success(struct) or Failure(errors)
      def call(id:, current_user:)
        # Check if user is ISMF staff
        unless ismf_staff?(current_user)
          return Failure(:unauthorized)
        end

        # Find the expense justification
        expenses_justification = @expenses_justification_repo.find(id)
        return Failure(:not_found) unless expenses_justification

        # Check if can mark as paid (must be approved and not already paid)
        unless expenses_justification.can_mark_as_paid?
          return Failure(:cannot_mark_as_paid)
        end

        # Update paid flag
        record = ExpensesJustification.find(id)
        record.update!(
          paid: true,
          paid_at: Time.current
        )

        # Broadcast update
        ExpensesJustificationBroadcaster.new.marked_as_paid(record)

        # Return updated struct
        updated_expenses_justification = @expenses_justification_repo.find(id)
        Success(updated_expenses_justification)
      rescue ActiveRecord::RecordInvalid => e
        Failure(record_invalid: e.message)
      rescue ActiveRecord::RecordNotFound
        Failure(:not_found)
      end

      private

      # Check if user is ISMF staff
      def ismf_staff?(user)
        user.role&.name == "ismf_staff"
      end
    end
  end
end