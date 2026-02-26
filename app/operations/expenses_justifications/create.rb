# frozen_string_literal: true

module Operations
  module ExpensesJustifications
    # Creates a new expenses justification
    #
    # Auto-fills personal and bank information from user profile if not provided.
    # Creates expense justification with status: draft.
    #
    # @example
    #   result = Operations::ExpensesJustifications::Create.new.call(
    #     user_id: 1,
    #     competition_id: 5,
    #     reason_of_travel: "WC Schladming 2024",
    #     charged_of: "VAR Referee",
    #     travel_start_date: "2024-02-28",
    #     travel_end_date: "2024-03-03",
    #     travel_days: 4,
    #     total_amount: 694.50
    #   )
    #
    class Create
      include Dry::Monads[:result]

      def initialize(expenses_justification_repo: AppContainer["repos.expenses_justification"])
        @expenses_justification_repo = expenses_justification_repo
      end

      # @param params [Hash] Input parameters
      # @param save_to_profile [Boolean] Whether to save data back to user profile (default: false)
      # @return [Dry::Monads::Result] Success(struct) or Failure(errors)
      def call(params, save_to_profile: false)
        # Validate input
        contract = Operations::Contracts::CreateExpensesJustification.new
        validation = contract.call(params)

        return Failure(validation.errors.to_h) unless validation.success?

        validated_params = validation.to_h

        # Auto-fill from user profile if not provided
        user = User.find(validated_params[:user_id])
        validated_params = auto_fill_user_data(validated_params, user)

        # Create the expense justification
        record = ExpensesJustification.create!(
          user_id: validated_params[:user_id],
          competition_id: validated_params[:competition_id],
          name: validated_params[:name],
          address: validated_params[:address],
          identity_document_number: validated_params[:identity_document_number],
          bank_swift: validated_params[:bank_swift],
          bank_iban: validated_params[:bank_iban],
          reason_of_travel: validated_params[:reason_of_travel],
          charged_of: validated_params[:charged_of],
          place: validated_params[:place],
          country: validated_params[:country],
          travel_start_date: validated_params[:travel_start_date],
          travel_end_date: validated_params[:travel_end_date],
          travel_days: validated_params[:travel_days],
          regular_transport: validated_params[:regular_transport] || {},
          private_vehicle: validated_params[:private_vehicle] || {},
          car_rental: validated_params[:car_rental] || {},
          other_travelling: validated_params[:other_travelling] || {},
          allowances: validated_params[:allowances] || {},
          accommodation: validated_params[:accommodation] || {},
          special_expenses: validated_params[:special_expenses] || {},
          total_amount: validated_params[:total_amount],
          status: "draft"
        )

        # Save data back to user profile if requested
        if save_to_profile
          update_user_profile(user, validated_params)
        end

        expenses_justification = @expenses_justification_repo.find(record.id)
        Success(expenses_justification)
      rescue ActiveRecord::RecordInvalid => e
        Failure(record_invalid: e.message)
      rescue ActiveRecord::RecordNotFound
        Failure(user_not_found: "User not found")
      end

      private

      # Auto-fill user data from profile if not provided
      def auto_fill_user_data(params, user)
        params[:name] ||= user.full_name || user.name
        params[:address] ||= user.address
        params[:identity_document_number] ||= user.identity_document_number
        params[:bank_swift] ||= user.bank_swift
        params[:bank_iban] ||= user.bank_iban
        params[:country] ||= user.country
        params
      end

      # Update user profile with expense data
      def update_user_profile(user, params)
        user.update(
          full_name: params[:name],
          address: params[:address],
          identity_document_number: params[:identity_document_number],
          bank_swift: params[:bank_swift],
          bank_iban: params[:bank_iban],
          country: params[:country]
        )
      end
    end
  end
end