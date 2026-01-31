# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Incidents::AttachPenalties do
  subject(:operation) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:race_location) { create(:race_location, race: race) }

  describe "#call" do
    context "attaching penalties to a pending incident" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty1) { create(:penalty, :false_start) }
      let!(:penalty2) { create(:penalty, :wrong_gate) }

      let(:valid_params) do
        {
          incident_id: incident.id,
          penalty_ids: [ penalty1.id, penalty2.id ]
        }
      end

      it "returns Success with an incident struct" do
        result = operation.call(valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
      end

      it "attaches the penalties to the incident" do
        result = operation.call(valid_params)

        expect(result.value!.penalties_count).to eq(2)
      end

      it "persists the penalty associations to the database" do
        operation.call(valid_params)

        incident.reload
        expect(incident.penalties).to contain_exactly(penalty1, penalty2)
      end

      it "creates incident_penalty records" do
        expect { operation.call(valid_params) }.to change(IncidentPenalty, :count).by(2)
      end
    end

    context "attaching a single penalty" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty) { create(:penalty, :false_start) }

      let(:valid_params) do
        {
          incident_id: incident.id,
          penalty_ids: [ penalty.id ]
        }
      end

      it "returns Success with an incident struct" do
        result = operation.call(valid_params)

        expect(result).to be_success
        expect(result.value!.penalties_count).to eq(1)
      end

      it "persists the penalty association" do
        operation.call(valid_params)

        incident.reload
        expect(incident.penalties).to contain_exactly(penalty)
      end
    end

    context "replacing existing penalties" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:old_penalty1) { create(:penalty, :false_start) }
      let!(:old_penalty2) { create(:penalty, :wrong_gate) }
      let!(:new_penalty1) { create(:penalty, :early_transition) }
      let!(:new_penalty2) { create(:penalty, :missing_equipment) }

      before do
        create(:incident_penalty, incident: incident, penalty: old_penalty1)
        create(:incident_penalty, incident: incident, penalty: old_penalty2)
      end

      let(:replace_params) do
        {
          incident_id: incident.id,
          penalty_ids: [ new_penalty1.id, new_penalty2.id ]
        }
      end

      it "removes old penalties and adds new ones" do
        operation.call(replace_params)

        incident.reload
        expect(incident.penalties).to contain_exactly(new_penalty1, new_penalty2)
        expect(incident.penalties).not_to include(old_penalty1, old_penalty2)
      end

      it "updates the penalties_count correctly" do
        result = operation.call(replace_params)

        expect(result.value!.penalties_count).to eq(2)
      end
    end

    context "clearing all penalties with empty array" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:existing_penalty) { create(:penalty, :false_start) }

      before do
        create(:incident_penalty, incident: incident, penalty: existing_penalty)
      end

      let(:clear_params) do
        {
          incident_id: incident.id,
          penalty_ids: []
        }
      end

      it "removes all penalties from the incident" do
        operation.call(clear_params)

        incident.reload
        expect(incident.penalties).to be_empty
      end

      it "returns incident with zero penalties_count" do
        result = operation.call(clear_params)

        expect(result.value!.penalties_count).to eq(0)
      end

      it "deletes the incident_penalty records" do
        expect { operation.call(clear_params) }.to change(IncidentPenalty, :count).by(-1)
      end
    end

    context "attaching penalties to an approved incident" do
      let!(:incident) { create(:incident, :approved, race: race, race_location: race_location) }
      let!(:penalty) { create(:penalty, :false_start) }

      let(:valid_params) do
        {
          incident_id: incident.id,
          penalty_ids: [ penalty.id ]
        }
      end

      it "allows attaching penalties to decided incidents" do
        result = operation.call(valid_params)

        expect(result).to be_success
        expect(result.value!.penalties_count).to eq(1)
      end
    end

    context "attaching penalties to a rejected incident" do
      let!(:incident) { create(:incident, :rejected, race: race, race_location: race_location) }
      let!(:penalty) { create(:penalty, :wrong_gate) }

      let(:valid_params) do
        {
          incident_id: incident.id,
          penalty_ids: [ penalty.id ]
        }
      end

      it "allows attaching penalties to rejected incidents" do
        result = operation.call(valid_params)

        expect(result).to be_success
        expect(result.value!.penalties_count).to eq(1)
      end
    end

    context "with duplicate penalty_ids" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty) { create(:penalty, :false_start) }

      let(:params_with_duplicates) do
        {
          incident_id: incident.id,
          penalty_ids: [ penalty.id, penalty.id, penalty.id ]
        }
      end

      it "deduplicates penalty_ids" do
        result = operation.call(params_with_duplicates)

        expect(result.value!.penalties_count).to eq(1)
      end

      it "creates only one incident_penalty record" do
        expect { operation.call(params_with_duplicates) }.to change(IncidentPenalty, :count).by(1)
      end
    end

    context "with nonexistent incident" do
      let!(:penalty) { create(:penalty, :false_start) }

      let(:invalid_params) do
        {
          incident_id: 999_999,
          penalty_ids: [ penalty.id ]
        }
      end

      it "returns Failure with validation error (contract validates first)" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:incident_id]).to include("incident not found")
      end
    end

    context "with nonexistent penalty_ids" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      let(:invalid_params) do
        {
          incident_id: incident.id,
          penalty_ids: [ 999_999, 999_998 ]
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:penalty_ids]).to include("one or more penalties not found")
      end

      it "does not modify existing penalties" do
        existing_penalty = create(:penalty, :false_start)
        create(:incident_penalty, incident: incident, penalty: existing_penalty)

        operation.call(invalid_params)

        incident.reload
        expect(incident.penalties).to contain_exactly(existing_penalty)
      end
    end

    context "with mix of valid and invalid penalty_ids" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:valid_penalty) { create(:penalty, :false_start) }

      let(:invalid_params) do
        {
          incident_id: incident.id,
          penalty_ids: [ valid_penalty.id, 999_999 ]
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:penalty_ids]).to include("one or more penalties not found")
      end

      it "does not attach any penalties" do
        operation.call(invalid_params)

        incident.reload
        expect(incident.penalties).to be_empty
      end
    end

    context "with missing required fields" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty) { create(:penalty, :false_start) }

      it "fails when incident_id is missing" do
        result = operation.call(penalty_ids: [ penalty.id ])

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:incident_id]).to include("is missing")
      end

      it "fails when penalty_ids is missing" do
        result = operation.call(incident_id: incident.id)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:penalty_ids]).to include("is missing")
      end
    end

    context "attaching many penalties" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalties) { create_list(:penalty, 5) }

      let(:many_penalties_params) do
        {
          incident_id: incident.id,
          penalty_ids: penalties.map(&:id)
        }
      end

      it "attaches all penalties successfully" do
        result = operation.call(many_penalties_params)

        expect(result).to be_success
        expect(result.value!.penalties_count).to eq(5)
      end

      it "persists all penalty associations" do
        operation.call(many_penalties_params)

        incident.reload
        expect(incident.penalties.count).to eq(5)
      end
    end

    context "transactional behavior" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:existing_penalty) { create(:penalty, :false_start) }
      let!(:new_penalty1) { create(:penalty, :wrong_gate) }
      let!(:new_penalty2) { create(:penalty, :early_transition) }

      before do
        create(:incident_penalty, incident: incident, penalty: existing_penalty)
      end

      it "replaces all penalties atomically" do
        operation.call(incident_id: incident.id, penalty_ids: [ new_penalty1.id, new_penalty2.id ])

        incident.reload
        expect(incident.penalties).to contain_exactly(new_penalty1, new_penalty2)
      end
    end

    context "with custom incident_repo" do
      let(:mock_repo) { instance_double(IncidentRepo) }
      let(:operation_with_repo) { described_class.new(incident_repo: mock_repo) }
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty) { create(:penalty, :false_start) }

      it "uses the injected repository" do
        expected_struct = Structs::Incident.new(
          id: incident.id,
          client_uuid: incident.client_uuid,
          race_id: race.id,
          race_location_id: race_location.id,
          status: "pending",
          description: nil,
          decided_by_user_id: nil,
          decided_at: nil,
          created_at: incident.created_at,
          updated_at: incident.updated_at,
          race_location_name: race_location.name,
          decided_by_user_name: nil,
          reports_count: 0,
          penalties_count: 1
        )

        allow(mock_repo).to receive(:find).with(incident.id).and_return(expected_struct)

        result = operation_with_repo.call(incident_id: incident.id, penalty_ids: [ penalty.id ])

        expect(result).to be_success
        expect(mock_repo).to have_received(:find).with(incident.id)
      end
    end

    context "idempotency" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty1) { create(:penalty, :false_start) }
      let!(:penalty2) { create(:penalty, :wrong_gate) }

      let(:same_params) do
        {
          incident_id: incident.id,
          penalty_ids: [ penalty1.id, penalty2.id ]
        }
      end

      it "produces the same result when called multiple times with same params" do
        result1 = operation.call(same_params)
        result2 = operation.call(same_params)

        expect(result1).to be_success
        expect(result2).to be_success
        expect(result1.value!.penalties_count).to eq(result2.value!.penalties_count)
      end

      it "does not create duplicate penalty associations" do
        operation.call(same_params)

        expect { operation.call(same_params) }.not_to change(IncidentPenalty, :count)
      end
    end
  end
end
