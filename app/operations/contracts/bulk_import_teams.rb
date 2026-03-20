# frozen_string_literal: true

require "dry-validation"

module Operations
  module Contracts
    # Contract for validating bulk team import JSON data for relay races.
    #
    # Each team entry requires:
    # - bib_number: integer (1-9999), unique across the import batch
    # - team_name: string (optional, auto-generated if absent)
    # - male: hash with first_name, last_name, country, optional license_number
    # - female: hash with first_name, last_name, country, optional license_number
    #
    # Example:
    #   contract = BulkImportTeams.new
    #   result = contract.call(
    #     race_id: 1,
    #     teams: [
    #       {
    #         bib_number: 1,
    #         team_name: "ITA Mixed 1",
    #         male:   { first_name: "Nadir",  last_name: "Maguet", country: "ITA" },
    #         female: { first_name: "Giulia", last_name: "Murada", country: "ITA" }
    #       }
    #     ]
    #   )
    #
    class BulkImportTeams < Dry::Validation::Contract
      ATHLETE_SCHEMA = Dry::Schema.Params do
        required(:first_name).filled(:string)
        required(:last_name).filled(:string)
        required(:country).filled(:string)
        optional(:license_number).maybe(:string)
      end

      params do
        required(:race_id).filled(:integer)
        required(:teams).array(:hash) do
          required(:bib_number).filled(:integer)
          optional(:team_name).maybe(:string)
          required(:male).hash do
            required(:first_name).filled(:string)
            required(:last_name).filled(:string)
            required(:country).filled(:string)
            optional(:license_number).maybe(:string)
          end
          required(:female).hash do
            required(:first_name).filled(:string)
            required(:last_name).filled(:string)
            required(:country).filled(:string)
            optional(:license_number).maybe(:string)
          end
        end
      end

      # Validate race exists
      rule(:race_id) do
        key.failure("race not found") unless Race.exists?(value)
      end

      # Validate teams array is not empty
      rule(:teams) do
        key.failure("must contain at least one team") if value.empty?
      end

      # Validate bib numbers are in range
      rule(:teams).each do
        next unless key? && value[:bib_number]

        if value[:bib_number] < 1 || value[:bib_number] > 9999
          key.failure("bib_number must be between 1 and 9999")
        end
      end

      # Validate no duplicate bib numbers in the import batch
      rule(:teams) do
        next unless key?

        bibs = value.map { |t| t[:bib_number] }.compact
        duplicates = bibs.select { |b| bibs.count(b) > 1 }.uniq

        key.failure("duplicate bib numbers: #{duplicates.join(', ')}") if duplicates.any?
      end

      # Validate country codes for male athletes
      rule(:teams).each do
        next unless key? && value.dig(:male, :country)

        country = value[:male][:country]

        unless country.match?(/\A[A-Z]{3}\z/)
          key.failure("male country must be a 3-letter code (e.g. ITA)")
        end

        unless IsmfRaceLogger::Types::ISMF_COUNTRIES.include?(country)
          key.failure("male country '#{country}' is not a valid ISMF country code")
        end
      end

      # Validate country codes for female athletes
      rule(:teams).each do
        next unless key? && value.dig(:female, :country)

        country = value[:female][:country]

        unless country.match?(/\A[A-Z]{3}\z/)
          key.failure("female country must be a 3-letter code (e.g. ITA)")
        end

        unless IsmfRaceLogger::Types::ISMF_COUNTRIES.include?(country)
          key.failure("female country '#{country}' is not a valid ISMF country code")
        end
      end
    end
  end
end