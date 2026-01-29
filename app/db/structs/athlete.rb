# frozen_string_literal: true

module Structs
  # Immutable domain object representing an Athlete
  #
  # This struct is returned by AthleteRepo methods and contains
  # all athlete data plus domain logic methods.
  #
  # Example:
  #   athlete = athlete_repo.find(1)
  #   athlete.full_name # => "John Doe"
  #   athlete.display_name # => "John DOE (ITA)"
  #
  class Athlete < DB::Struct
    attribute :id, Types::Integer
    attribute :first_name, Types::String
    attribute :last_name, Types::String
    attribute :country, Types::CountryCode
    attribute :license_number, Types::String.optional
    attribute :gender, Types::Gender
    attribute :created_at, Types::OptionalDateTime
    attribute :updated_at, Types::OptionalDateTime

    # Returns full name with proper capitalization
    #
    # @return [String] "John Doe"
    def full_name
      "#{first_name} #{last_name}"
    end

    # Returns display name with uppercase last name and country
    #
    # @return [String] "John DOE (ITA)"
    def display_name
      "#{first_name} #{last_name.upcase} (#{country})"
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

    # Returns country flag emoji (if needed later)
    #
    # @return [String] country code for now
    def country_display
      country
    end
  end
end