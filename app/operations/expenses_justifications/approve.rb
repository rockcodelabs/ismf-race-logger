# frozen_string_literal: true

module Operations
  module ExpensesJustifications
    # Approves an expenses justification
    #
    # Changes status from "sent" to "approved" and sets approval metadata.
    # Triggers email notification to the user.
    # Only ISMF staff can approve.
    #
    # @example
    #   result = Operations::ExpensesJustifications::Approve.new.call(
    #     id: 1,
    #     current_user: ismf_staff_user
    #   )
    #
    class Approve
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

        # Check if can approve (must be sent)
        unless expenses_justification.can_approve?
          return Failure(:cannot_approve)
        end

        # Update status to approved
        record = ExpensesJustification.find(id)
        record.update!(
          status: "approved",
          approved_at: Time.current,
          approved_by_id: current_user.id
        )

        # Send notification email to user
        ExpensesJustificationMailer.approved(record).deliver_later

        # Broadcast update
        ExpensesJustificationBroadcaster.new.approved(record)

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