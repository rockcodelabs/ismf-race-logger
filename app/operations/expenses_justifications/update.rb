# frozen_string_literal: true

module Operations
  module ExpensesJustifications
    # Updates an existing expenses justification
    #
    # Only allows updates when status is "draft" (for regular users).
    # ISMF staff can update at any status.
    #
    # @example
    #   result = Operations::ExpensesJustifications::Update.new.call(
    #     id: 1,
    #     total_amount: 750.00,
    #     travel_days: 5
    #   )
    #
    class Update
      include Dry::Monads[:result]

      def initialize(expenses_justification_repo: AppContainer["repos.expenses_justification"])
        @expenses_justification_repo = expenses_justification_repo
      end

      # @param id [Integer] Expense justification ID
      # @param params [Hash] Fields to update
      # @param current_user [User] Current user (for authorization)
      # @param save_to_profile [Boolean] Whether to save data back to user profile (default: false)
      # @return [Dry::Monads::Result] Success(struct) or Failure(errors)
      def call(id:, params:, current_user: nil, save_to_profile: false)
        # Find the expense justification
        expenses_justification = @expenses_justification_repo.find(id)
        return Failure(:not_found) unless expenses_justification

        # Check if user can edit (draft only, unless ISMF staff)
        unless can_edit?(expenses_justification, current_user)
          return Failure(:cannot_edit_after_submission)
        end

        # Validate input
        contract = Operations::Contracts::UpdateExpensesJustification.new
        validation = contract.call(params)

        return Failure(validation.errors.to_h) unless validation.success?

        validated_params = validation.to_h

        # Update the record
        record = ExpensesJustification.find(id)
        record.update!(validated_params)

        # Save data back to user profile if requested
        if save_to_profile
          user = User.find(record.user_id)
          update_user_profile(user, record)
        end

        # Return updated struct
        updated_expenses_justification = @expenses_justification_repo.find(id)
        Success(updated_expenses_justification)
      rescue ActiveRecord::RecordInvalid => e
        Failure(record_invalid: e.message)
      rescue ActiveRecord::RecordNotFound
        Failure(:not_found)
      end

      private

      # Check if user can edit this expense justification
      def can_edit?(expenses_justification, current_user)
        return true unless current_user # Skip check if no user context

        # ISMF staff can always edit
        return true if ismf_staff?(current_user)

        # Regular users can only edit drafts
        expenses_justification.draft?
      end

      # Check if user is ISMF staff
      def ismf_staff?(user)
        user.role&.name == "ismf_staff"
      end

      # Update user profile with expense data
      def update_user_profile(user, record)
        user.update(
          full_name: record.name,
          address: record.address,
          identity_document_number: record.identity_document_number,
          bank_swift: record.bank_swift,
          bank_iban: record.bank_iban,
          country: record.country
        )
      end
    end
  end
end