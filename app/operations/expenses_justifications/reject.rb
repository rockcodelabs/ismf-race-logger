# frozen_string_literal: true

module Operations
  module ExpensesJustifications
    # Rejects an expenses justification
    #
    # Changes status from "sent" to "rejected" and sets rejection metadata.
    # Triggers email notification to the user with rejection reason.
    # Only ISMF staff can reject.
    #
    # @example
    #   result = Operations::ExpensesJustifications::Reject.new.call(
    #     id: 1,
    #     current_user: ismf_staff_user,
    #     rejection_reason: "Missing receipt for accommodation"
    #   )
    #
    class Reject
      include Dry::Monads[:result]

      def initialize(expenses_justification_repo: AppContainer["repos.expenses_justification"])
        @expenses_justification_repo = expenses_justification_repo
      end

      # @param id [Integer] Expense justification ID
      # @param current_user [User] Current user (must be ISMF staff)
      # @param rejection_reason [String] Reason for rejection
      # @return [Dry::Monads::Result] Success(struct) or Failure(errors)
      def call(id:, current_user:, rejection_reason: nil)
        # Check if user is ISMF staff
        unless ismf_staff?(current_user)
          return Failure(:unauthorized)
        end

        # Find the expense justification
        expenses_justification = @expenses_justification_repo.find(id)
        return Failure(:not_found) unless expenses_justification

        # Check if can reject (must be sent)
        unless expenses_justification.can_reject?
          return Failure(:cannot_reject)
        end

        # Validate rejection reason is provided
        if rejection_reason.blank?
          return Failure(rejection_reason: ["must be provided"])
        end

        # Update status to rejected
        record = ExpensesJustification.find(id)
        record.update!(
          status: "rejected",
          rejected_at: Time.current,
          rejected_by_id: current_user.id,
          rejection_reason: rejection_reason
        )

        # Send notification email to user
        ExpensesJustificationMailer.rejected(record).deliver_later

        # Broadcast update
        ExpensesJustificationBroadcaster.new.rejected(record)

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