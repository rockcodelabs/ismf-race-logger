# frozen_string_literal: true

module Operations
  module ExpensesJustifications
    # Submits an expenses justification for approval
    #
    # Changes status from "draft" to "sent" and sets submitted_at timestamp.
    # Triggers email notification to ISMF staff.
    #
    # @example
    #   result = Operations::ExpensesJustifications::Submit.new.call(
    #     id: 1,
    #     current_user: user
    #   )
    #
    class Submit
      include Dry::Monads[:result]

      def initialize(expenses_justification_repo: AppContainer["repos.expenses_justification"])
        @expenses_justification_repo = expenses_justification_repo
      end

      # @param id [Integer] Expense justification ID
      # @param current_user [User] Current user (for authorization)
      # @return [Dry::Monads::Result] Success(struct) or Failure(errors)
      def call(id:, current_user:)
        # Find the expense justification
        expenses_justification = @expenses_justification_repo.find(id)
        return Failure(:not_found) unless expenses_justification

        # Check if user owns this expense justification
        unless expenses_justification.user_id == current_user.id
          return Failure(:unauthorized)
        end

        # Check if can submit (must be draft)
        unless expenses_justification.can_submit?
          return Failure(:cannot_submit)
        end

        # Validate required fields are present
        validation_errors = validate_required_fields(expenses_justification)
        return Failure(validation_errors) if validation_errors.any?

        # Update status to sent
        record = ExpensesJustification.find(id)
        record.update!(
          status: "sent",
          submitted_at: Time.current
        )

        # Send notification email to ISMF staff
        ExpensesJustificationMailer.submitted(record).deliver_later

        # Broadcast update
        ExpensesJustificationBroadcaster.new.submitted(record)

        # Return updated struct
        updated_expenses_justification = @expenses_justification_repo.find(id)
        Success(updated_expenses_justification)
      rescue ActiveRecord::RecordInvalid => e
        Failure(record_invalid: e.message)
      rescue ActiveRecord::RecordNotFound
        Failure(:not_found)
      end

      private

      # Validate that all required fields are present before submission
      def validate_required_fields(expenses_justification)
        errors = {}

        if expenses_justification.name.blank?
          errors[:name] = ["must be present"]
        end

        if expenses_justification.address.blank?
          errors[:address] = ["must be present"]
        end

        if expenses_justification.identity_document_number.blank?
          errors[:identity_document_number] = ["must be present"]
        end

        if expenses_justification.bank_swift.blank?
          errors[:bank_swift] = ["must be present"]
        end

        if expenses_justification.bank_iban.blank?
          errors[:bank_iban] = ["must be present"]
        end

        if expenses_justification.total_amount <= 0
          errors[:total_amount] = ["must be greater than 0"]
        end

        errors
      end
    end
  end
end