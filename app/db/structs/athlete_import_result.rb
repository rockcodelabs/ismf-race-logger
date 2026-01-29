# frozen_string_literal: true

module Structs
  # Summary result of a bulk athlete import operation
  #
  # This struct is returned by Operations::Athletes::BulkImport
  # and contains statistics about the import process.
  #
  # Example:
  #   result = Operations::Athletes::BulkImport.new.call(race_id: 1, json_data: data)
  #   if result.success?
  #     summary = result.value!
  #     summary.total_count # => 10
  #     summary.new_athletes_count # => 3
  #     summary.existing_athletes_count # => 7
  #   end
  #
  AthleteImportResult = Data.define(
    :total_count,
    :new_athletes_count,
    :existing_athletes_count,
    :participations_created,
    :errors
  ) do
    # Checks if import was completely successful
    #
    # @return [Boolean]
    def success?
      errors.empty?
    end

    # Returns a human-readable summary message
    #
    # @return [String] "5 athletes imported: 3 new, 2 existing"
    def summary_message
      "#{total_count} athlete#{'s' unless total_count == 1} imported: " \
        "#{new_athletes_count} new, #{existing_athletes_count} existing"
    end

    # Returns count of athletes that failed to import
    #
    # @return [Integer]
    def failed_count
      errors.size
    end

    # Returns a default empty result
    #
    # @return [AthleteImportResult]
    def self.empty
      new(
        total_count: 0,
        new_athletes_count: 0,
        existing_athletes_count: 0,
        participations_created: 0,
        errors: []
      )
    end
  end
end