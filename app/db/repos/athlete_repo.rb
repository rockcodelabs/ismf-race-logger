# frozen_string_literal: true

# Repository for Athlete data access
#
# This repo handles all database queries for athletes and returns
# immutable Structs::Athlete or Structs::AthleteSummary objects.
#
# Example:
#   athlete_repo = AthleteRepo.new
#   athlete = athlete_repo.find_or_create_by(
#     first_name: "John",
#     last_name: "Doe",
#     gender: "M",
#     country: "ITA"
#   )
#
class AthleteRepo < DB::Repo
    returns_one :find_by_license, :find_by_name
    returns_many :all, :search, :by_country

    # Find athlete by license number
    #
    # @param license_number [String] Athlete's license number
    # @return [Structs::Athlete, nil]
    def find_by_license(license_number)
      base_scope.find_by(license_number: license_number)
    end

    # Find athlete by name, gender, and country
    #
    # @param first_name [String]
    # @param last_name [String]
    # @param gender [String] "M" or "F"
    # @param country [String] ISO 3166-1 alpha-3 country code
    # @return [Structs::Athlete, nil]
    def find_by_name(first_name:, last_name:, gender:, country:)
      base_scope.find_by(
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        country: country
      )
    end

    # Find or create athlete by name, gender, and country
    #
    # This is the primary method for athlete import - it finds an existing
    # athlete or creates a new one if not found.
    #
    # @param first_name [String]
    # @param last_name [String]
    # @param gender [String] "M" or "F"
    # @param country [String] ISO 3166-1 alpha-3 country code
    # @param license_number [String, nil] Optional license number
    # @return [Array<Structs::Athlete, Boolean>] [athlete, created?]
    def find_or_create_by(first_name:, last_name:, gender:, country:, license_number: nil)
      athlete = find_by_name(
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        country: country
      )

      if athlete
        [athlete, false]
      else
        record = Athlete.create!(
          first_name: first_name,
          last_name: last_name,
          gender: gender,
          country: country,
          license_number: license_number
        )
        [build_struct(record), true]
      end
    end

    # Search athletes by name
    #
    # @param query [String] Search query (searches first and last name)
    # @return [Array<Structs::AthleteSummary>]
    def search(query)
      base_scope
        .where("first_name ILIKE ? OR last_name ILIKE ?", "%#{query}%", "%#{query}%")
        .order(:last_name, :first_name)
    end

    # Get athletes by country
    #
    # @param country_code [String] ISO 3166-1 alpha-3 country code
    # @return [Array<Structs::AthleteSummary>]
    def by_country(country_code)
      base_scope
        .where(country: country_code)
        .order(:last_name, :first_name)
    end

    # Get all athletes
    #
    # @return [Array<Structs::AthleteSummary>]
    def all
      base_scope.order(:last_name, :first_name)
    end

    protected

    def record_class
      Athlete
    end

    def base_scope
      Athlete.all
    end

    def build_struct(record)
      Structs::Athlete.new(
        id: record.id,
        first_name: record.first_name,
        last_name: record.last_name,
        country: record.country,
        license_number: record.license_number,
        gender: record.gender,
        created_at: record.created_at,
        updated_at: record.updated_at
      )
    end

    def build_summary(record)
      Structs::AthleteSummary.new(
        id: record.id,
        first_name: record.first_name,
        last_name: record.last_name,
        country: record.country,
        gender: record.gender,
        license_number: record.license_number
      )
    end
  end