# frozen_string_literal: true

module Operations
  module Contracts
    # Validates input for {{action}} {{resource}}
    #
    # @example
    #   contract = Operations::Contracts::{{Action}}{{Resource}}.new
    #   result = contract.call(name: "Example", status: "active")
    #   result.success? # => true/false
    #   result.errors.to_h # => { name: ["must be filled"] }
    #
    class {{Action}}{{Resource}} < Dry::Validation::Contract
      params do
        # Required fields
        required(:name).filled(:string)
        required(:status).filled(:string)

        # Optional fields
        optional(:description).maybe(:string)

        # Add resource-specific validations:
        # required(:email).filled(:string)
        # required(:bib_number).filled(:integer)
        # optional(:metadata).maybe(:hash)
      end

      # Custom validation rules
      rule(:name) do
        key.failure("must be at least 3 characters") if value && value.length < 3
      end

      # @example Email validation
      # rule(:email) do
      #   unless /\A[^@\s]+@[^@\s]+\z/.match?(value)
      #     key.failure("must be a valid email")
      #   end
      # end

      # @example Cross-field validation
      # rule(:end_date, :start_date) do
      #   if values[:end_date] && values[:start_date]
      #     key(:end_date).failure("must be after start date") if values[:end_date] < values[:start_date]
      #   end
      # end

      # @example Status enum validation
      # rule(:status) do
      #   valid_statuses = %w[pending active completed]
      #   key.failure("must be one of: #{valid_statuses.join(', ')}") unless valid_statuses.include?(value)
      # end
    end
  end
end

# Placeholders:
#   {{Action}}   - Operation action (e.g., Create, Update)
#   {{Resource}} - Singular resource name (e.g., Incident)
#   {{resource}} - Lowercase singular (e.g., incident)