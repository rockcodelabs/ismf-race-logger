# frozen_string_literal: true

module Operations
  module Competitions
    # Create a new competition
    #
    # This operation:
    # - Validates input parameters using CreateCompetition contract
    # - Creates the competition record
    # - Returns the created competition as a struct
    #
    # @example
    #   result = Operations::Competitions::Create.new.call(
    #     name: "World Cup Verbier 2024",
    #     city: "Verbier",
    #     place: "Swiss Alps",
    #     country: "CHE",
    #     description: "Annual ISMF World Cup competition",
    #     start_date: Date.new(2024, 1, 15),
    #     end_date: Date.new(2024, 1, 17),
    #     webpage_url: "https://www.ismf-ski.org"
    #   )
    #
    #   case result
    #   in Success(competition)
    #     # competition is a Structs::Competition
    #   in Failure(errors)
    #     # errors is a hash of validation errors
    #   end
    #
    class Create
      include Dry::Monads[:result]
      include Import[competition_repo: "repos.competition"]

      # @param params [Hash] Input parameters
      # @return [Dry::Monads::Result] Success(Structs::Competition) or Failure(errors)
      def call(params)
        # Validate input
        contract = Operations::Contracts::CreateCompetition.new
        validation = contract.call(params)

        return Failure([:validation_failed, validation.errors.to_h]) unless validation.success?

        # Create competition via injected repo
        created_competition = competition_repo.create(validation.to_h)

        return Failure(:create_failed) unless created_competition

        Success(created_competition)
      rescue ActiveRecord::RecordInvalid => e
        Failure([:database_error, e.message])
      rescue StandardError => e
        Failure([:unexpected_error, e.message])
      end
    end
  end
end