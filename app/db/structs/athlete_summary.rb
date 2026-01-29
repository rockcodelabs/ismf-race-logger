# frozen_string_literal: true

module Structs
  # Lightweight summary representation of an Athlete for collections
  #
  # Used for lists, dropdowns, and other UI elements where full struct is not needed.
  # This is a Ruby Data object (not dry-struct) for better performance in collections.
  #
  # Example:
  #   athletes = athlete_repo.all
  #   athletes.first.display_name # => "John DOE (ITA)"
  #
  AthleteSummary = Data.define(
    :id,
    :first_name,
    :last_name,
    :country,
    :gender,
    :license_number
  ) do
    # Returns display name with uppercase last name and country
    #
    # @return [String] "John DOE (ITA)"
    def display_name
      "#{first_name} #{last_name.upcase} (#{country})"
    end

    # Returns full name with proper capitalization
    #
    # @return [String] "John Doe"
    def full_name
      "#{first_name} #{last_name}"
    end

    # Returns country display
    #
    # @return [String] country code
    def country_display
      country
    end

    # Checks if athlete is male
    #
    # @return [Boolean]
    def male?
      gender == "M"
    end

    # Checks if athlete is female
    #
    # @return [Boolean]
    def female?
      gender == "F"
    end
  end
end