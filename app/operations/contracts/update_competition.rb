# frozen_string_literal: true

module Operations
  module Contracts
    # Contract for updating an existing competition
    #
    # Validates all required fields and business rules:
    # - All fields required except logo
    # - end_date must be after start_date
    # - country must be valid ISO 3166-1 alpha-3 code
    # - webpage_url must be valid URL format
    #
    # Example:
    #   contract = Operations::Contracts::UpdateCompetition.new
    #   result = contract.call(
    #     name: "World Cup Verbier 2024",
    #     city: "Verbier",
    #     place: "Swiss Alps",
    #     country: "CHE",
    #     description: "Updated description...",
    #     start_date: Date.new(2024, 1, 15),
    #     end_date: Date.new(2024, 1, 17),
    #     webpage_url: "https://www.ismf-ski.org"
    #   )
    #
    #   if result.success?
    #     # Proceed with update
    #   else
    #     result.errors.to_h # => { end_date: ["must be after start date"] }
    #   end
    #
    class UpdateCompetition < Dry::Validation::Contract
      params do
        required(:name).filled(:string)
        required(:city).filled(:string)
        required(:place).filled(:string)
        required(:country).filled(:string)
        required(:description).filled(:string)
        required(:start_date).filled(:date)
        required(:end_date).filled(:date)
        required(:webpage_url).filled(:string)
      end

      rule(:country) do
        unless Types::CountryCode.valid?(value)
          key.failure("must be a valid ISO 3166-1 alpha-3 country code")
        end
      end

      rule(:end_date, :start_date) do
        if values[:end_date] && values[:start_date] && values[:end_date] < values[:start_date]
          key(:end_date).failure("must be after start date")
        end
      end

      rule(:webpage_url) do
        next if value.blank?

        uri = URI.parse(value)
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          key.failure("must be a valid HTTP or HTTPS URL")
        end
      rescue URI::InvalidURIError
        key.failure("must be a valid URL")
      end
    end
  end
end