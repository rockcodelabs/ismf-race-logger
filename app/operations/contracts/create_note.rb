# frozen_string_literal: true

module Operations
  module Contracts
    # Validates input for creating a note
    #
    # @example
    #   contract = Operations::Contracts::CreateNote.new
    #   result = contract.call(notable_type: "Report", notable_id: 29, user_id: 1, body: "Note text")
    #   result.success? # => true
    #
    class CreateNote < Dry::Validation::Contract
      params do
        required(:notable_type).filled(:string)
        required(:notable_id).filled(:integer)
        required(:user_id).filled(:integer)
        required(:body).filled(:string)
      end

      rule(:notable_type) do
        key.failure("must be Report or Incident") unless %w[Report Incident].include?(value)
      end

      rule(:body) do
        key.failure("must not be blank") if value&.strip&.empty?
      end
    end
  end
end