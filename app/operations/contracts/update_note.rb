# frozen_string_literal: true

module Operations
  module Contracts
    # Validates input for updating a note
    #
    # @example
    #   contract = Operations::Contracts::UpdateNote.new
    #   result = contract.call(note_id: 1, body: "Updated text")
    #   result.success? # => true
    #
    class UpdateNote < Dry::Validation::Contract
      params do
        required(:note_id).filled(:integer)
        required(:body).filled(:string)
      end

      rule(:body) do
        key.failure("must not be blank") if value&.strip&.empty?
      end
    end
  end
end