# frozen_string_literal: true

module Operations
  module Contracts
    # CreateIncident Contract
    #
    # Validates input parameters for creating an incident by merging reports.
    # An incident is created from one or more confirmed reports.
    #
    # Required fields:
    # - report_ids: array of integers (at least one confirmed report)
    #
    # Optional fields:
    # - description: string (summary/notes about the incident)
    # - race_location_id: integer (defaults to first report's location)
    #
    class CreateIncident < Dry::Validation::Contract
      params do
        required(:report_ids).filled(:array)
        optional(:description).maybe(:string)
        optional(:race_location_id).maybe(:integer)
      end

      # Validate report_ids contains at least one report
      rule(:report_ids) do
        key.failure("must contain at least one report") if value.empty?
      end

      # Validate all report_ids are integers
      rule(:report_ids) do
        next if value.empty?

        key.failure("must contain only integer IDs") unless value.all? { |id| id.is_a?(Integer) }
      end

      # Validate all reports exist and are confirmed
      rule(:report_ids) do
        next if value.empty?

        reports = Report.where(id: value)

        # Check all reports exist
        if reports.count != value.size
          key.failure("one or more reports not found")
          next
        end

        # Check all reports are confirmed
        non_confirmed = reports.where.not(status: "confirmed")
        if non_confirmed.exists?
          key.failure("all reports must be confirmed before merging into an incident")
          next
        end

        # Check no reports are already linked to an incident
        already_linked = reports.where.not(incident_id: nil)
        if already_linked.exists?
          key.failure("one or more reports are already linked to an incident")
          next
        end

        # Check all reports belong to the same race
        race_ids = reports.pluck(:race_id).uniq
        key.failure("all reports must belong to the same race") if race_ids.size > 1
      end

      # Validate race_location_id if provided
      rule(:race_location_id, :report_ids) do
        next if values[:race_location_id].nil?
        next if values[:report_ids].empty?

        # Get the race_id from the first report
        first_report = Report.find_by(id: values[:report_ids].first)
        next unless first_report

        location = RaceLocation.find_by(id: values[:race_location_id])
        if location.nil?
          key(:race_location_id).failure("must be a valid race location")
        elsif location.race_id != first_report.race_id
          key(:race_location_id).failure("must belong to the same race as the reports")
        end
      end
    end
  end
end
