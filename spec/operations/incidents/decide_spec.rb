# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Incidents::Decide do
  subject(:operation) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:decider) { create(:user, name: "Decision Maker") }
  let(:race_location) { create(:race_location, race: race) }

  describe "#call" do
    context "approving a pending incident" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      let(:valid_params) do
        {
          id: incident.id,
          status: "approved",
          user_id: decider.id
        }
      end

      it "returns Success with an incident struct" do
        result = operation.call(valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
      end

      it "updates the status to approved" do
        result = operation.call(valid_params)

        expect(result.value!.status).to eq("approved")
      end

      it "persists the status change to the database" do
        operation.call(valid_params)

        incident.reload
        expect(incident.status).to eq("approved")
      end

      it "records who made the decision" do
        result = operation.call(valid_params)

        expect(result.value!.decided_by_user_id).to eq(decider.id)
        expect(result.value!.decided_by_user_name).to eq("Decision Maker")
      end

      it "records when the decision was made" do
        freeze_time do
          result = operation.call(valid_params)

          expect(result.value!.decided_at).to be_within(1.second).of(Time.current)
        end
      end

      it "persists decision metadata to the database" do
        freeze_time do
          operation.call(valid_params)

          incident.reload
          expect(incident.decided_by_user_id).to eq(decider.id)
          expect(incident.decided_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    context "rejecting a pending incident" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      let(:reject_params) do
        {
          id: incident.id,
          status: "rejected",
          user_id: decider.id
        }
      end

      it "returns Success with an incident struct" do
        result = operation.call(reject_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
      end

      it "updates the status to rejected" do
        result = operation.call(reject_params)

        expect(result.value!.status).to eq("rejected")
      end

      it "persists the status change to the database" do
        operation.call(reject_params)

        incident.reload
        expect(incident.status).to eq("rejected")
      end

      it "records who made the decision" do
        result = operation.call(reject_params)

        expect(result.value!.decided_by_user_id).to eq(decider.id)
      end
    end

    context "with optional description" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      let(:params_with_description) do
        {
          id: incident.id,
          status: "approved",
          user_id: decider.id,
          description: "Clear violation observed on video review"
        }
      end

      it "stores the description" do
        result = operation.call(params_with_description)

        expect(result.value!.description).to eq("Clear violation observed on video review")
      end

      it "persists the description to the database" do
        operation.call(params_with_description)

        incident.reload
        expect(incident.description).to eq("Clear violation observed on video review")
      end
    end

    context "with penalties" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty1) { create(:penalty, :false_start) }
      let!(:penalty2) { create(:penalty, :wrong_gate) }

      let(:params_with_penalties) do
        {
          id: incident.id,
          status: "approved",
          user_id: decider.id,
          penalty_ids: [ penalty1.id, penalty2.id ]
        }
      end

      it "attaches penalties to the incident" do
        result = operation.call(params_with_penalties)

        expect(result.value!.penalties_count).to eq(2)
      end

      it "persists penalty associations to the database" do
        operation.call(params_with_penalties)

        incident.reload
        expect(incident.penalties).to contain_exactly(penalty1, penalty2)
      end

      it "creates incident_penalty records" do
        expect { operation.call(params_with_penalties) }.to change(IncidentPenalty, :count).by(2)
      end
    end

    context "updating penalties when deciding a pending incident" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:old_penalty) { create(:penalty, :false_start) }
      let!(:new_penalty1) { create(:penalty, :wrong_gate) }
      let!(:new_penalty2) { create(:penalty, :early_transition) }

      before do
        # Attach an old penalty to the pending incident
        create(:incident_penalty, incident: incident, penalty: old_penalty)
      end

      let(:params_with_new_penalties) do
        {
          id: incident.id,
          status: "approved",
          user_id: decider.id,
          penalty_ids: [ new_penalty1.id, new_penalty2.id ]
        }
      end

      it "replaces existing penalties with new ones" do
        operation.call(params_with_new_penalties)

        incident.reload
        expect(incident.penalties).to contain_exactly(new_penalty1, new_penalty2)
        expect(incident.penalties).not_to include(old_penalty)
      end
    end

    context "with duplicate penalty_ids" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty) { create(:penalty, :false_start) }

      let(:params_with_duplicates) do
        {
          id: incident.id,
          status: "approved",
          user_id: decider.id,
          penalty_ids: [ penalty.id, penalty.id, penalty.id ]
        }
      end

      it "rejects duplicates at contract level (size mismatch)" do
        result = operation.call(params_with_duplicates)

        # Contract checks value.size vs existing_count, so duplicates fail validation
        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:penalty_ids]).to include("contains invalid penalty IDs")
      end

      it "accepts unique penalty_ids" do
        result = operation.call(
          id: incident.id,
          status: "approved",
          user_id: decider.id,
          penalty_ids: [ penalty.id ]
        )

        expect(result).to be_success
        expect(result.value!.penalties_count).to eq(1)
      end
    end

    context "with nonexistent incident" do
      let(:invalid_params) do
        {
          id: 999_999,
          status: "approved",
          user_id: decider.id
        }
      end

      it "returns Failure with validation error (contract validates existence)" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:id]).to include("incident not found")
      end
    end

    context "with invalid status" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      let(:invalid_params) do
        {
          id: incident.id,
          status: "invalid_status",
          user_id: decider.id
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:status]).to be_present
      end

      it "does not change the incident status" do
        operation.call(invalid_params)

        incident.reload
        expect(incident.status).to eq("pending")
      end
    end

    context "with missing required fields" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      it "fails when id is missing" do
        result = operation.call(status: "approved", user_id: decider.id)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:id]).to include("is missing")
      end

      it "fails when status is missing" do
        result = operation.call(id: incident.id, user_id: decider.id)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:status]).to include("is missing")
      end

      it "fails when user_id is missing" do
        result = operation.call(id: incident.id, status: "approved")

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:user_id]).to include("is missing")
      end
    end

    context "with nonexistent user_id" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      let(:invalid_params) do
        {
          id: incident.id,
          status: "approved",
          user_id: 999_999
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:user_id]).to include("must be a valid user")
      end
    end

    context "with nonexistent penalty_ids" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      let(:invalid_params) do
        {
          id: incident.id,
          status: "approved",
          user_id: decider.id,
          penalty_ids: [ 999_999, 999_998 ]
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:penalty_ids]).to include("contains invalid penalty IDs")
      end
    end

    context "deciding multiple incidents" do
      let!(:incident1) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:incident2) { create(:incident, :pending, race: race, race_location: race_location) }

      it "decides each incident independently" do
        result1 = operation.call(id: incident1.id, status: "approved", user_id: decider.id)
        result2 = operation.call(id: incident2.id, status: "rejected", user_id: decider.id)

        expect(result1).to be_success
        expect(result2).to be_success
        expect(result1.value!.status).to eq("approved")
        expect(result2.value!.status).to eq("rejected")
      end
    end

    context "re-deciding an already decided incident" do
      let!(:original_decider) { create(:user, name: "Original Decider") }
      let!(:incident) do
        create(:incident, :approved,
               race: race,
               race_location: race_location,
               decided_by_user: original_decider,
               decided_at: 1.hour.ago)
      end

      let(:re_decide_params) do
        {
          id: incident.id,
          status: "rejected",
          user_id: decider.id,
          description: "Decision reversed after further review"
        }
      end

      it "fails because incident must be pending to decide" do
        result = operation.call(re_decide_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:id]).to include("incident must be pending to decide (current status: approved)")
      end

      it "does not change the incident status" do
        operation.call(re_decide_params)

        incident.reload
        expect(incident.status).to eq("approved")
      end

      context "after reopening the incident first" do
        before do
          Operations::Incidents::Reopen.new.call(id: incident.id)
          incident.reload
        end

        it "allows changing the decision" do
          result = operation.call(re_decide_params)

          expect(result).to be_success
          expect(result.value!.status).to eq("rejected")
        end

        it "updates the decider to the new user" do
          result = operation.call(re_decide_params)

          expect(result.value!.decided_by_user_id).to eq(decider.id)
        end

        it "updates the decided_at timestamp" do
          freeze_time do
            result = operation.call(re_decide_params)

            expect(result.value!.decided_at).to be_within(1.second).of(Time.current)
          end
        end
      end
    end

    context "transactional behavior" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }
      let!(:penalty1) { create(:penalty, :false_start) }
      let!(:penalty2) { create(:penalty, :wrong_gate) }

      it "updates status and attaches penalties in a transaction" do
        result = operation.call(
          id: incident.id,
          status: "approved",
          user_id: decider.id,
          penalty_ids: [ penalty1.id, penalty2.id ]
        )

        expect(result).to be_success

        incident.reload
        expect(incident.status).to eq("approved")
        expect(incident.penalties).to contain_exactly(penalty1, penalty2)
      end
    end

    context "with custom incident_repo" do
      let(:mock_repo) { instance_double(IncidentRepo) }
      let(:operation_with_repo) { described_class.new(incident_repo: mock_repo) }
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      it "uses the injected repository" do
        expected_struct = Structs::Incident.new(
          id: incident.id,
          client_uuid: incident.client_uuid,
          race_id: race.id,
          race_location_id: race_location.id,
          status: "approved",
          description: nil,
          decided_by_user_id: decider.id,
          decided_at: Time.current,
          created_at: incident.created_at,
          updated_at: incident.updated_at,
          race_location_name: race_location.name,
          decided_by_user_name: decider.display_name,
          reports_count: 0,
          penalties_count: 0
        )

        allow(mock_repo).to receive(:find).with(incident.id).and_return(expected_struct)

        result = operation_with_repo.call(id: incident.id, status: "approved", user_id: decider.id)

        expect(result).to be_success
        expect(mock_repo).to have_received(:find).with(incident.id)
      end
    end
  end
end
