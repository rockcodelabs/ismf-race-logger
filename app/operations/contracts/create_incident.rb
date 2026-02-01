# frozen_string_literal: true

module Operations
  module Contracts
    # CreateIncident Contract
    #
    # Validates input parameters for creating an incident by merging reports.
    # An incident is created from one or more reports (pending_review or confirmed).
    # Reports will be automatically confirmed when the incident is created.
    #
    # Required fields:
    # - report_ids: array of integers (at least one report)
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

        # Allow both pending_review and confirmed reports
        # (Reports will be confirmed when incident is created)
        invalid_status = reports.where.not(status: %w[pending_review confirmed])
        if invalid_status.exists?
          key.failure("reports must be pending_review or confirmed (cannot use rejected reports)")
          next
        end

        # Note: We now ALLOW reports that are already linked to incidents
        # They will be moved to the new incident (frontend handles confirmation)

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
