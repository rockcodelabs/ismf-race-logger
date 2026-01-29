# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Athletes::BulkImport do
  subject(:operation) { described_class.new }

  let(:competition) { Competition.create!(name: "Test Competition", city: "Test City", place: "Test Place", country: "ITA", description: "Test Description", webpage_url: "https://example.com", start_date: Date.today, end_date: Date.today + 1) }
  let(:race_type) { RaceType.create!(name: "Individual") }
  let(:race) { Race.create!(competition: competition, race_type: race_type, name: "Test Race", stage_name: "Final", stage_type: "Final", position: 0, status: "scheduled") }

  describe "#call" do
    context "with valid JSON data" do
      let(:athletes_json) do
        [
          {
            bib_number: 1,
            first_name: "John",
            last_name: "Doe",
            gender: "M",
            country: "ITA",
            license_number: "ABC123"
          },
          {
            bib_number: 2,
            first_name: "Jane",
            last_name: "Smith",
            gender: "F",
            country: "USA"
          }
        ].to_json
      end

      it "imports athletes successfully" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_success
        summary = result.value!
        expect(summary.total_count).to eq(2)
        expect(summary.new_athletes_count).to eq(2)
        expect(summary.existing_athletes_count).to eq(0)
        expect(summary.participations_created).to eq(2)
        expect(summary.errors).to be_empty
      end

      it "creates athlete records" do
        expect {
          operation.call(race_id: race.id, athletes_json: athletes_json)
        }.to change(Athlete, :count).by(2)
      end

      it "creates race participation records" do
        expect {
          operation.call(race_id: race.id, athletes_json: athletes_json)
        }.to change(RaceParticipation, :count).by(2)
      end

      it "assigns correct bib numbers" do
        operation.call(race_id: race.id, athletes_json: athletes_json)

        participation1 = RaceParticipation.find_by(race_id: race.id, bib_number: 1)
        participation2 = RaceParticipation.find_by(race_id: race.id, bib_number: 2)

        expect(participation1).to be_present
        expect(participation2).to be_present
        expect(participation1.athlete.first_name).to eq("John")
        expect(participation2.athlete.first_name).to eq("Jane")
      end
    end

    context "with existing athletes" do
      let!(:existing_athlete) do
        Athlete.create!(
          first_name: "John",
          last_name: "Doe",
          gender: "M",
          country: "ITA",
          license_number: "OLD123"
        )
      end

      let(:athletes_json) do
        [
          {
            bib_number: 1,
            first_name: "John",
            last_name: "Doe",
            gender: "M",
            country: "ITA",
            license_number: "NEW123"
          }
        ].to_json
      end

      it "reuses existing athlete" do
        expect {
          operation.call(race_id: race.id, athletes_json: athletes_json)
        }.not_to change(Athlete, :count)
      end

      it "counts as existing athlete" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_success
        summary = result.value!
        expect(summary.new_athletes_count).to eq(0)
        expect(summary.existing_athletes_count).to eq(1)
      end
    end

    context "with invalid JSON" do
      let(:athletes_json) { "{ invalid json" }

      it "returns failure with parse error" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_failure
        expect(result.failure).to include("Invalid JSON format")
      end
    end

    context "with duplicate bib numbers in JSON" do
      let(:athletes_json) do
        [
          { bib_number: 1, first_name: "John", last_name: "Doe", gender: "M", country: "ITA" },
          { bib_number: 1, first_name: "Jane", last_name: "Smith", gender: "F", country: "USA" }
        ].to_json
      end

      it "returns validation failure" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_failure
        expect(result.failure).to be_a(Hash)
      end
    end

    context "with athlete already in race" do
      let!(:athlete) { Athlete.create!(first_name: "John", last_name: "Doe", gender: "M", country: "ITA") }
      let!(:participation) { RaceParticipation.create!(race: race, athlete: athlete, bib_number: 99) }

      let(:athletes_json) do
        [
          { bib_number: 1, first_name: "John", last_name: "Doe", gender: "M", country: "ITA" }
        ].to_json
      end

      it "returns failure with error message" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_failure
        expect(result.failure[:errors]).to be_present
        expect(result.failure[:errors].first).to include("already assigned")
      end
    end

    context "with bib number already taken" do
      let!(:athlete) { Athlete.create!(first_name: "John", last_name: "Doe", gender: "M", country: "ITA") }
      let!(:participation) { RaceParticipation.create!(race: race, athlete: athlete, bib_number: 1) }

      let(:athletes_json) do
        [
          { bib_number: 1, first_name: "Jane", last_name: "Smith", gender: "F", country: "USA" }
        ].to_json
      end

      it "returns failure with error message" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_failure
        expect(result.failure[:errors]).to be_present
        expect(result.failure[:errors].first).to include("already assigned")
      end
    end

    context "with missing required fields" do
      let(:athletes_json) do
        [
          { bib_number: 1, first_name: "John" }
        ].to_json
      end

      it "returns validation failure" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_failure
        expect(result.failure).to be_a(Hash)
      end
    end

    context "with invalid gender" do
      let(:athletes_json) do
        [
          { bib_number: 1, first_name: "John", last_name: "Doe", gender: "X", country: "ITA" }
        ].to_json
      end

      it "returns validation failure" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_failure
      end
    end

    context "with invalid country code" do
      let(:athletes_json) do
        [
          { bib_number: 1, first_name: "John", last_name: "Doe", gender: "M", country: "INVALID" }
        ].to_json
      end

      it "returns validation failure" do
        result = operation.call(race_id: race.id, athletes_json: athletes_json)

        expect(result).to be_failure
      end
    end

    context "with non-existent race" do
      let(:athletes_json) do
        [
          { bib_number: 1, first_name: "John", last_name: "Doe", gender: "M", country: "ITA" }
        ].to_json
      end

      it "returns validation failure" do
        result = operation.call(race_id: 99999, athletes_json: athletes_json)

        expect(result).to be_failure
      end
    end
  end
end