# frozen_string_literal: true

require "dry-validation"

module Operations
  module Contracts
    # Contract for validating bulk athlete import JSON data
    #
    # This contract validates the structure of the JSON array and each athlete object.
    # It ensures all required fields are present and have valid values.
    #
    # Example:
    #   contract = BulkImportAthletes.new
    #   result = contract.call(
    #     race_id: 1,
    #     athletes: [
    #       {
    #         bib_number: 1,
    #         first_name: "John",
    #         last_name: "Doe",
    #         gender: "M",
    #         country: "ITA"
    #       }
    #     ]
    #   )
    #
    class BulkImportAthletes < Dry::Validation::Contract
      params do
        required(:race_id).filled(:integer)
        required(:athletes).array(:hash) do
          required(:bib_number).filled(:integer)
          required(:first_name).filled(:string)
          required(:last_name).filled(:string)
          required(:gender).filled(:string)
          required(:country).filled(:string)
          optional(:license_number).maybe(:string)
        end
      end

      # Validate race exists
      rule(:race_id) do
        key.failure("race not found") unless Race.exists?(value)
      end

      # Validate athletes array is not empty
      rule(:athletes) do
        key.failure("must contain at least one athlete") if value.empty?
      end

      # Validate gender values
      rule(:athletes).each do
        if key? && value[:gender]
          unless %w[M F].include?(value[:gender])
            key.failure("must be 'M' or 'F'")
          end
        end
      end

      # Validate country codes
      rule(:athletes).each do
        if key? && value[:country]
          unless value[:country].match?(/\A[A-Z]{3}\z/)
            key.failure("must be a 3-letter country code (e.g., 'ITA', 'USA')")
          end

          unless IsmfRaceLogger::Types::ISMF_COUNTRIES.include?(value[:country])
            key.failure("'#{value[:country]}' is not a valid ISMF country code")
          end
        end
      end

      # Validate bib numbers are positive
      rule(:athletes).each do
        if key? && value[:bib_number]
          if value[:bib_number] < 1 || value[:bib_number] > 9999
            key.failure("bib number must be between 1 and 9999")
          end
        end
      end

      # Validate no duplicate bib numbers in the array
      rule(:athletes) do
        if key?
          bib_numbers = value.map { |a| a[:bib_number] }.compact
          duplicates = bib_numbers.select { |bib| bib_numbers.count(bib) > 1 }.uniq

          unless duplicates.empty?
            key.failure("duplicate bib numbers found: #{duplicates.join(', ')}")
          end
        end
      end
    end
  end
end