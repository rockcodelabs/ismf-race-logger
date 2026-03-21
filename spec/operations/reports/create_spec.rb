# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Reports::Create do
  subject(:operation) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:user) { create(:user) }
  let(:var_user) { create(:user, :var_operator) }
  let(:race_location) { create(:race_location, race: race) }
  let(:athlete) { create(:athlete) }
  let(:participation) { create(:race_participation, race: race, athlete: athlete, bib_number: 42) }

  describe "#call" do
    context "with valid params" do
      let(:valid_params) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id
        }
      end

      it "returns Success with a report struct" do
        result = operation.call(**valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Report)
      end

      it "creates a report in the database" do
        expect { operation.call(**valid_params) }.to change(Report, :count).by(1)
      end

      it "sets the status to pending_review for non-VAR users" do
        result = operation.call(**valid_params)

        expect(result.value!.status).to eq("pending_review")
      end

      it "does not create an incident for non-VAR users" do
        expect { operation.call(**valid_params) }.not_to change(Incident, :count)
      end

      it "sets all required fields correctly" do
        result = operation.call(**valid_params)

        report = result.value!
        expect(report.race_id).to eq(race.id)
        expect(report.race_location_id).to eq(race_location.id)
        expect(report.race_participation_id).to eq(participation.id)
        expect(report.bib_number).to eq(42)
        expect(report.user_id).to eq(user.id)
      end

      it "generates a client_uuid if not provided" do
        result = operation.call(**valid_params)

        expect(result.value!.client_uuid).to be_present
        expect(result.value!.client_uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      end

      it "includes associated data in the returned struct" do
        result = operation.call(**valid_params)

        report = result.value!
        expect(report.race_location_name).to eq(race_location.name)
        expect(report.athlete_name).to eq("#{athlete.first_name} #{athlete.last_name}")
        expect(report.user_name).to eq(user.display_name)
      end
    end

    context "when user is VAR operator" do
      let(:var_params) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: var_user.id
        }
      end

      it "returns Success with a report struct" do
        result = operation.call(**var_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Report)
      end

      it "creates a report in the database" do
        expect { operation.call(**var_params) }.to change(Report, :count).by(1)
      end

      it "auto-creates an incident" do
        expect { operation.call(**var_params) }.to change(Incident, :count).by(1)
      end

      it "links the report to the incident" do
        result = operation.call(**var_params)
        report = result.value!

        expect(report.incident_id).to be_present
      end

      it "sets incident status to pending" do
        result = operation.call(**var_params)
        report = Report.find(result.value!.id)
        incident = report.incident

        expect(incident.status).to eq("pending")
      end

      it "sets incident race_location from report" do
        result = operation.call(**var_params)
        report = Report.find(result.value!.id)
        incident = report.incident

        expect(incident.race_location_id).to eq(race_location.id)
      end

      it "sets incident description from report" do
        params_with_desc = var_params.merge(description: "VAR observed infraction")
        result = operation.call(params_with_desc)
        report = Report.find(result.value!.id)
        incident = report.incident

        expect(incident.description).to eq("VAR observed infraction")
      end

      it "keeps report status as pending_review" do
        result = operation.call(**var_params)

        expect(result.value!.status).to eq("pending_review")
      end
    end

    context "with optional params" do
      let(:params_with_options) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id,
          athlete_position: 1,
          description: "Potential false start observed"
        }
      end

      it "stores the description" do
        result = operation.call(params_with_options)

        expect(result.value!.description).to eq("Potential false start observed")
      end

      it "stores the athlete_position" do
        result = operation.call(params_with_options)

        expect(result.value!.athlete_position).to eq(1)
      end
    end

    context "with client_uuid (idempotency)" do
      let(:client_uuid) { "550e8400-e29b-41d4-a716-446655440000" }
      let(:params_with_uuid) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id,
          client_uuid: client_uuid
        }
      end

      it "uses the provided client_uuid" do
        result = operation.call(params_with_uuid)

        expect(result.value!.client_uuid).to eq(client_uuid)
      end

      it "returns existing report if client_uuid already exists" do
        # First call creates the report
        first_result = operation.call(params_with_uuid)
        existing_report = first_result.value!

        # Second call should return the same report
        second_result = operation.call(params_with_uuid)

        expect(second_result).to be_success
        expect(second_result.value!.id).to eq(existing_report.id)
      end

      it "does not create a duplicate report for same client_uuid" do
        operation.call(params_with_uuid)

        expect { operation.call(params_with_uuid) }.not_to change(Report, :count)
      end
    end

    context "with invalid race (not in_progress)" do
      let(:scheduled_race) { create(:race, :scheduled, competition: competition, race_type: race_type) }
      let(:scheduled_location) { create(:race_location, race: scheduled_race) }
      let(:scheduled_participation) { create(:race_participation, race: scheduled_race) }

      let(:invalid_params) do
        {
          race_id: scheduled_race.id,
          race_location_id: scheduled_location.id,
          race_participation_id: scheduled_participation.id,
          bib_number: scheduled_participation.bib_number,
          user_id: user.id
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure).to eq([ :validation_failed, { race_id: [ "race must be in progress to create reports" ] } ])
      end

      it "does not create a report" do
        expect { operation.call(**invalid_params) }.not_to change(Report, :count)
      end
    end

    context "with completed race" do
      let(:completed_race) { create(:race, :completed, competition: competition, race_type: race_type) }
      let(:completed_location) { create(:race_location, race: completed_race) }
      let(:completed_participation) { create(:race_participation, race: completed_race) }

      let(:invalid_params) do
        {
          race_id: completed_race.id,
          race_location_id: completed_location.id,
          race_participation_id: completed_participation.id,
          bib_number: completed_participation.bib_number,
          user_id: user.id
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:race_id]).to include("race must be in progress to create reports")
      end
    end

    context "with nonexistent race" do
      let(:invalid_params) do
        {
          race_id: 999_999,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:race_id]).to include("must be a valid race")
      end
    end

    context "with race_location from different race" do
      let(:other_race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
      let(:other_location) { create(:race_location, race: other_race) }

      let(:invalid_params) do
        {
          race_id: race.id,
          race_location_id: other_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:race_location_id]).to include("must belong to the specified race")
      end
    end

    context "with race_participation from different race" do
      let(:other_race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
      let(:other_participation) { create(:race_participation, race: other_race) }

      let(:invalid_params) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: other_participation.id,
          bib_number: other_participation.bib_number,
          user_id: user.id
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:race_participation_id]).to include("must belong to the specified race")
      end
    end

    context "with invalid bib_number" do
      let(:invalid_params) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: 0,
          user_id: user.id
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:bib_number]).to include("must be between 1 and 9999")
      end
    end

    context "with invalid athlete_position" do
      let(:invalid_params) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id,
          athlete_position: 3
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:athlete_position]).to include("must be 1 or 2")
      end
    end

    context "with invalid client_uuid format" do
      let(:invalid_params) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id,
          client_uuid: "not-a-valid-uuid"
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:client_uuid]).to include("must be a valid UUID format")
      end
    end

    context "with missing required fields" do
      it "fails when race_id is missing" do
        result = operation.call(
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id
        )

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:race_id]).to include("is missing")
      end

      it "fails when race_location_id is missing" do
        result = operation.call(
          race_id: race.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: user.id
        )

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:race_location_id]).to include("is missing")
      end

      it "fails when user_id is missing" do
        result = operation.call(
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number
        )

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:user_id]).to include("is missing")
      end
    end

    context "with nonexistent user" do
      let(:invalid_params) do
        {
          race_id: race.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          user_id: 999_999
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:user_id]).to include("must be a valid user")
      end
    end
  end
end
