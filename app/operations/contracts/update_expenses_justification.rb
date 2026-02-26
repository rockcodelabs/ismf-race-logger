# frozen_string_literal: true

module Operations
  module Contracts
    # Validates input for updating an expenses justification
    #
    # All fields are optional to allow partial updates.
    # Only provided fields will be validated and updated.
    #
    # @example
    #   contract = Operations::Contracts::UpdateExpensesJustification.new
    #   result = contract.call(name: "John Doe", total_amount: 500.00)
    #   result.success? # => true/false
    #   result.errors.to_h # => { name: ["must be filled"] }
    #
    class UpdateExpensesJustification < Dry::Validation::Contract
      params do
        # Personal Information
        optional(:name).filled(:string)
        optional(:address).filled(:string)
        optional(:identity_document_number).filled(:string)

        # Bank Information
        optional(:bank_swift).filled(:string)
        optional(:bank_iban).filled(:string)

        # Trip Details
        optional(:reason_of_travel).filled(:string)
        optional(:charged_of).maybe(:string)
        optional(:place).maybe(:string)
        optional(:country).maybe(:string)
        optional(:travel_start_date).filled(:date)
        optional(:travel_end_date).filled(:date)
        optional(:travel_days).filled(:integer)

        # Expense Line Items (JSONB)
        optional(:regular_transport).maybe(:hash)
        optional(:private_vehicle).maybe(:hash)
        optional(:car_rental).maybe(:hash)
        optional(:other_travelling).maybe(:hash)
        optional(:allowances).maybe(:hash)
        optional(:accommodation).maybe(:hash)
        optional(:special_expenses).maybe(:hash)

        # Total
        optional(:total_amount).filled(:decimal)
      end

      # Validate name length
      rule(:name) do
        key.failure("must be at least 2 characters") if value && value.length < 2
      end

      # Validate travel dates
      rule(:travel_end_date, :travel_start_date) do
        if values[:travel_end_date] && values[:travel_start_date]
          if values[:travel_end_date] < values[:travel_start_date]
            key(:travel_end_date).failure("must be on or after start date")
          end
        end
      end

      # Validate travel days is positive
      rule(:travel_days) do
        key.failure("must be greater than 0") if value && value <= 0
      end

      # Validate total amount is positive
      rule(:total_amount) do
        key.failure("must be greater than or equal to 0") if value && value < 0
      end

      # Validate SWIFT code format (8 or 11 characters)
      rule(:bank_swift) do
        if value && !value.match?(/\A[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?\z/)
          key.failure("must be a valid SWIFT/BIC code")
        end
      end

      # Validate IBAN format (basic check)
      rule(:bank_iban) do
        if value && value.gsub(/\s/, "").length < 15
          key.failure("must be a valid IBAN")
        end
      end
    end
  end
end