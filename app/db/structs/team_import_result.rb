# frozen_string_literal: true

module Structs
  # Summary result of a bulk team import operation
  #
  # Returned by Operations::Teams::BulkImport
  # Contains statistics about the relay team import process.
  #
  # Example:
  #   result = Operations::Teams::BulkImport.new.call(race_id: 1, teams_json: data)
  #   if result.success?
  #     summary = result.value!
  #     summary.total_count        # => 10
  #     summary.new_athletes_count # => 8
  #   end
  #
  TeamImportResult = Data.define(
    :total_count,
    :new_athletes_count,
    :errors
  ) do
    # @return [Boolean]
    def success?
      errors.empty?
    end

    # @return [String] "10 teams imported (8 new athletes)"
    def summary_message
      "#{total_count} team#{'s' unless total_count == 1} imported " \
        "(#{new_athletes_count} new athlete#{'s' unless new_athletes_count == 1})"
    end

    # @return [Integer]
    def failed_count
      errors.size
    end

    # @return [TeamImportResult]
    def self.empty
      new(total_count: 0, new_athletes_count: 0, errors: [])
    end
  end
end