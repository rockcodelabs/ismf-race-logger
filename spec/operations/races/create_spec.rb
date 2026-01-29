# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Races::Create do
  subject(:operation) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }

  describe "#call" do
    context "with valid params" do
      let(:valid_params) do
        {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Women's Sprint - Qualification",
          stage_type: "Qualification",
          heat_number: nil,
          scheduled_at: Time.current + 2.hours
        }
      end

      it "returns Success with Structs::Race" do
        result = operation.call(valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Race)
      end

      it "creates a race in the database" do
        expect { operation.call(valid_params) }.to change(Race, :count).by(1)
      end

      it "sets the race attributes correctly" do
        result = operation.call(valid_params)
        race = result.value!

        expect(race.name).to eq("Women's Sprint - Qualification")
        expect(race.stage_type).to eq("Qualification")
        expect(race.heat_number).to be_nil
        expect(race.competition_id).to eq(competition.id)
        expect(race.race_type_id).to eq(race_type.id)
      end

      it "computes stage_name from stage_type (no heat)" do
        result = operation.call(valid_params)
        race = result.value!

        expect(race.stage_name).to eq("Qualification")
      end

      it "computes stage_name from stage_type and heat_number" do
        params = valid_params.merge(stage_type: "Semifinal", heat_number: 2)
        result = operation.call(params)
        race = result.value!

        expect(race.stage_name).to eq("Semifinal 2")
      end

      it "auto-assigns position (first race in race_type)" do
        result = operation.call(valid_params)
        race = result.value!

        expect(race.position).to eq(0)
      end

      it "auto-assigns next position when races already exist" do
        create(:race, competition: competition, race_type: race_type, position: 0)
        create(:race, competition: competition, race_type: race_type, position: 1)

        result = operation.call(valid_params)
        race = result.value!

        expect(race.position).to eq(2)
      end

      it "sets default status to scheduled" do
        result = operation.call(valid_params)
        race = result.value!

        expect(race.status).to eq("scheduled")
      end

      it "allows scheduled_at to be nil" do
        params = valid_params.merge(scheduled_at: nil)
        result = operation.call(params)

        expect(result).to be_success
        expect(result.value!.scheduled_at).to be_nil
      end
    end

    context "with invalid params" do
      it "returns Failure when competition_id is missing" do
        params = {
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "Final"
        }

        result = operation.call(params)

        expect(result).to be_failure
        expect(result.failure).to be_a(Hash)
      end

      it "returns Failure when race_type_id is missing" do
        params = {
          competition_id: competition.id,
          name: "Test Race",
          stage_type: "Final"
        }

        result = operation.call(params)

        expect(result).to be_failure
      end

      it "returns Failure when name is missing" do
        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          stage_type: "Final"
        }

        result = operation.call(params)

        expect(result).to be_failure
      end

      it "returns Failure when stage_type is missing" do
        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Test Race"
        }

        result = operation.call(params)

        expect(result).to be_failure
      end

      it "returns Failure when stage_type is invalid" do
        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "InvalidStage"
        }

        result = operation.call(params)

        expect(result).to be_failure
        expect(result.failure[:stage_type]).to be_present
      end

      it "returns Failure when heat_number is out of range" do
        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "Semifinal",
          heat_number: 99
        }

        result = operation.call(params)

        expect(result).to be_failure
        expect(result.failure[:heat_number]).to be_present
      end

      it "returns Failure when competition doesn't exist" do
        params = {
          competition_id: 999999,
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "Final"
        }

        result = operation.call(params)

        expect(result).to be_failure
        expect(result.failure[:competition_id]).to be_present
      end

      it "returns Failure when race_type doesn't exist" do
        params = {
          competition_id: competition.id,
          race_type_id: 999999,
          name: "Test Race",
          stage_type: "Final"
        }

        result = operation.call(params)

        expect(result).to be_failure
        expect(result.failure[:race_type_id]).to be_present
      end

      it "returns Failure when name is too short" do
        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "ab",
          stage_type: "Final"
        }

        result = operation.call(params)

        expect(result).to be_failure
        expect(result.failure[:name]).to be_present
      end
    end

    context "stage_name computation" do
      let(:base_params) do
        {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Test Race"
        }
      end

      it "computes 'Qualification' for Qualification stage without heat" do
        params = base_params.merge(stage_type: "Qualification")
        result = operation.call(params)

        expect(result.value!.stage_name).to eq("Qualification")
      end

      it "computes 'Heat 3' for Heat stage with heat number" do
        params = base_params.merge(stage_type: "Heat", heat_number: 3)
        result = operation.call(params)

        expect(result.value!.stage_name).to eq("Heat 3")
      end

      it "computes 'Semifinal 1' for Semifinal stage with heat number" do
        params = base_params.merge(stage_type: "Semifinal", heat_number: 1)
        result = operation.call(params)

        expect(result.value!.stage_name).to eq("Semifinal 1")
      end

      it "computes 'Final' for Final stage without heat" do
        params = base_params.merge(stage_type: "Final")
        result = operation.call(params)

        expect(result.value!.stage_name).to eq("Final")
      end
    end

    context "position computation" do
      it "positions races within same race_type correctly" do
        sprint_type = create(:race_type_sprint)
        individual_type = create(:race_type_individual)

        # Create races for sprint
        create(:race, competition: competition, race_type: sprint_type, position: 0)
        create(:race, competition: competition, race_type: sprint_type, position: 1)

        # Create races for individual
        create(:race, competition: competition, race_type: individual_type, position: 0)

        # New sprint race should get position 2
        params = {
          competition_id: competition.id,
          race_type_id: sprint_type.id,
          name: "New Sprint Race",
          stage_type: "Final"
        }

        result = operation.call(params)
        expect(result.value!.position).to eq(2)

        # New individual race should get position 1
        params = {
          competition_id: competition.id,
          race_type_id: individual_type.id,
          name: "New Individual Race",
          stage_type: "Final"
        }

        result = operation.call(params)
        expect(result.value!.position).to eq(1)
      end

      it "positions races per competition (not globally)" do
        competition2 = create(:competition)

        # Create races in first competition
        create(:race, competition: competition, race_type: race_type, position: 0)
        create(:race, competition: competition, race_type: race_type, position: 1)

        # New race in second competition should start at 0
        params = {
          competition_id: competition2.id,
          race_type_id: race_type.id,
          name: "Race in Competition 2",
          stage_type: "Final"
        }

        result = operation.call(params)
        expect(result.value!.position).to eq(0)
      end
    end

    context "error handling" do
      it "handles database errors gracefully" do
        # Simulate database error by causing a validation failure
        allow_any_instance_of(Race).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(Race.new))

        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "Final"
        }

        result = operation.call(params)

        expect(result).to be_failure
        expect(result.failure[:database]).to be_present
      end

      it "handles unexpected errors gracefully" do
        # Simulate unexpected error in the operation itself
        repo = instance_double(RaceRepo)
        allow(repo).to receive(:create).and_raise(StandardError.new("Unexpected error"))
        
        operation_with_mock = described_class.new(race: repo)

        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "Final"
        }

        result = operation_with_mock.call(params)

        expect(result).to be_failure
        expect(result.failure[:unexpected]).to be_present
      end
    end

    context "dry-monads integration" do
      it "returns a Dry::Monads::Result" do
        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "Final"
        }

        result = operation.call(params)

        expect(result).to respond_to(:success?)
        expect(result).to respond_to(:failure?)
        expect(result).to respond_to(:value!)
      end

      it "can be pattern matched on Success" do
        params = {
          competition_id: competition.id,
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "Final"
        }

        result = operation.call(params)

        matched = case result
        in Dry::Monads::Success(race)
          race.name
        in Dry::Monads::Failure
          "failed"
        end

        expect(matched).to eq("Test Race")
      end

      it "can be pattern matched on Failure" do
        params = { name: "Invalid" }

        result = operation.call(params)

        matched = case result
        in Dry::Monads::Success
          "success"
        in Dry::Monads::Failure(errors)
          errors.class.name
        end

        expect(matched).to eq("Hash")
      end
    end
  end
end