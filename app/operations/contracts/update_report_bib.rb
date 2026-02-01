# frozen_string_literal: true

module Operations
  module Contracts
    # UpdateReportBib Contract
    #
    # Validates input parameters for updating a report's bib number.
    # Used when a report was created with "Number NN" (unknown bib) and
    # needs to be assigned to a specific athlete later.
    #
    # Required fields:
    # - report_id: integer (must exist)
    # - race_participation_id: integer (must belong to the same race)
    # - bib_number: integer (must match the participation)
    #
    class UpdateReportBib < Dry::Validation::Contract
      params do
        required(:report_id).filled(:integer)
        required(:race_participation_id).filled(:integer)
        required(:bib_number).filled(:integer)
      end

      # Validate report exists
      rule(:report_id) do
        report = Report.find_by(id: value)
        key.failure("must be a valid report") if report.nil?
      end

      # Validate race_participation exists
      rule(:race_participation_id) do
        participation = RaceParticipation.find_by(id: value)
        key.failure("must be a valid race participation") if participation.nil?
      end

      # Validate race_participation belongs to the same race as the report
      rule(:race_participation_id, :report_id) do
        next unless values[:report_id] && values[:race_participation_id]

        report = Report.find_by(id: values[:report_id])
        participation = RaceParticipation.find_by(id: values[:race_participation_id])

        if report && participation
          if participation.race_id != report.race_id
            key(:race_participation_id).failure("must belong to the same race as the report")
          end
        end
      end

      # Validate bib_number matches the participation
      rule(:bib_number, :race_participation_id) do
        next unless values[:bib_number] && values[:race_participation_id]

        participation = RaceParticipation.find_by(id: values[:race_participation_id])

        if participation && participation.bib_number != values[:bib_number]
          key(:bib_number).failure("must match the participation's bib number (#{participation.bib_number})")
        end
      end

      # Validate bib_number is valid
      rule(:bib_number) do
        key.failure("must be between 1 and 9999") unless value.between?(1, 9999)
      end
    end
  end
end