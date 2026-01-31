# frozen_string_literal: true

module Operations
  module Competitions
    # Update an existing competition
    #
    # This operation:
    # - Validates input parameters using UpdateCompetition contract
    # - Updates the competition record
    # - Returns the updated competition as a struct
    #
    # @example
    #   result = Operations::Competitions::Update.new.call(
    #     id: 1,
    #     name: "World Cup Verbier 2025",
    #     city: "Verbier",
    #     place: "Swiss Alps",
    #     country: "CHE",
    #     description: "Updated description",
    #     start_date: Date.new(2025, 1, 15),
    #     end_date: Date.new(2025, 1, 17),
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
    class Update
      include Dry::Monads[:result]
      include Import[competition_repo: "repos.competition"]

      # @param id [Integer] Competition ID
      # @param params [Hash] Input parameters
      # @return [Dry::Monads::Result] Success(Structs::Competition) or Failure(errors)
      def call(id, params = {})
        return Failure(:not_found) unless id

        # Check competition exists
        existing = competition_repo.find(id)
        return Failure([:not_found, "Competition not found"]) unless existing

        # Use params directly (id is separate argument now)
        update_attrs = params

        # Merge existing values with update params (allows partial updates)
        # This ensures all required fields are present for validation
        merged_attrs = {
          name: existing.name,
          city: existing.city,
          place: existing.place,
          country: existing.country,
          description: existing.description,
          start_date: existing.start_date,
          end_date: existing.end_date,
          webpage_url: existing.webpage_url
        }.merge(update_attrs)

        # Validate input
        contract = Operations::Contracts::UpdateCompetition.new
        validation = contract.call(merged_attrs)

        return Failure([:validation_failed, validation.errors.to_h]) unless validation.success?

        # Update competition via injected repo
        updated_competition = competition_repo.update(id, validation.to_h)

        return Failure(:update_failed) unless updated_competition

        Success(updated_competition)
      rescue ActiveRecord::RecordNotFound
        Failure([:not_found, "Competition not found"])
      rescue ActiveRecord::RecordInvalid => e
        Failure([:database_error, e.message])
      rescue StandardError => e
        Failure([:unexpected_error, e.message])
      end
    end
  end
end