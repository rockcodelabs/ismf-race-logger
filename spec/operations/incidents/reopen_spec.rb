# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Incidents::Reopen do
  subject(:operation) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:decider) { create(:user, name: "Decision Maker") }
  let(:race_location) { create(:race_location, race: race) }

  describe "#call" do
    context "with an approved incident" do
      let!(:incident) do
        create(:incident, :approved,
               race: race,
               race_location: race_location,
               decided_by_user: decider,
               decided_at: 1.hour.ago)
      end

      it "returns Success with an incident struct" do
        result = operation.call(id: incident.id)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
      end

      it "updates the status to pending" do
        result = operation.call(id: incident.id)

        expect(result.value!.status).to eq("pending")
      end

      it "persists the status change to the database" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.status).to eq("pending")
      end

      it "clears the decided_at timestamp" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.decided_at).to be_nil
      end

      it "clears the decided_by_user_id" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.decided_by_user_id).to be_nil
      end

      it "returns the incident with all associations" do
        result = operation.call(id: incident.id)

        returned_incident = result.value!
        expect(returned_incident.id).to eq(incident.id)
        expect(returned_incident.race_id).to eq(race.id)
        expect(returned_incident.race_location_name).to eq(race_location.name)
      end
    end

    context "with a rejected incident" do
      let!(:incident) do
        create(:incident, :rejected,
               race: race,
               race_location: race_location,
               decided_by_user: decider,
               decided_at: 2.hours.ago)
      end

      it "returns Success with an incident struct" do
        result = operation.call(id: incident.id)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
      end

      it "updates the status to pending" do
        result = operation.call(id: incident.id)

        expect(result.value!.status).to eq("pending")
      end

      it "persists the status change to the database" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.status).to eq("pending")
      end

      it "clears the decision metadata" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.decided_at).to be_nil
        expect(incident.decided_by_user_id).to be_nil
      end
    end

    context "with an already pending incident" do
      let!(:incident) { create(:incident, :pending, race: race, race_location: race_location) }

      it "returns Failure with already_pending error" do
        result = operation.call(id: incident.id)

        expect(result).to be_failure
        expect(result.failure).to eq(:already_pending)
      end

      it "does not change the incident status" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.status).to eq("pending")
      end
    end

    context "with nonexistent incident" do
      it "returns Failure with not_found error" do
        result = operation.call(id: 999_999)

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end
    end

    context "with incident that has penalties attached" do
      let!(:incident) do
        create(:incident, :approved,
               race: race,
               race_location: race_location,
               decided_by_user: decider)
      end
      let!(:penalty1) { create(:penalty, :false_start) }
      let!(:penalty2) { create(:penalty, :wrong_gate) }

      before do
        create(:incident_penalty, incident: incident, penalty: penalty1)
        create(:incident_penalty, incident: incident, penalty: penalty2)
      end

      it "reopens the incident successfully" do
        result = operation.call(id: incident.id)

        expect(result).to be_success
        expect(result.value!.status).to eq("pending")
      end

      it "preserves the penalties (does not remove them)" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.penalties).to contain_exactly(penalty1, penalty2)
      end
    end

    context "with incident that has linked reports" do
      let!(:incident) do
        create(:incident, :approved,
               race: race,
               race_location: race_location,
               decided_by_user: decider)
      end
      let(:participation) { create(:race_participation, race: race) }
      let!(:linked_report) do
        create(:report, :confirmed,
               race: race,
               race_location: race_location,
               race_participation: participation,
               incident: incident)
      end

      it "reopens the incident successfully" do
        result = operation.call(id: incident.id)

        expect(result).to be_success
        expect(result.value!.status).to eq("pending")
      end

      it "preserves the linked reports" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.reports).to include(linked_report)
      end
    end

    context "reopening multiple incidents" do
      let!(:incident1) do
        create(:incident, :approved,
               race: race,
               race_location: race_location,
               decided_by_user: decider)
      end
      let!(:incident2) do
        create(:incident, :rejected,
               race: race,
               race_location: race_location,
               decided_by_user: decider)
      end

      it "reopens each incident independently" do
        result1 = operation.call(id: incident1.id)
        result2 = operation.call(id: incident2.id)

        expect(result1).to be_success
        expect(result2).to be_success
        expect(result1.value!.status).to eq("pending")
        expect(result2.value!.status).to eq("pending")
      end
    end

    context "preserves other incident attributes" do
      let!(:incident) do
        create(:incident, :approved,
               race: race,
               race_location: race_location,
               decided_by_user: decider,
               description: "Original description from decision")
      end

      it "preserves the description" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.description).to eq("Original description from decision")
      end

      it "preserves the race_location_id" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.race_location_id).to eq(race_location.id)
      end

      it "preserves the race_id" do
        operation.call(id: incident.id)

        incident.reload
        expect(incident.race_id).to eq(race.id)
      end
    end

    context "with custom incident_repo" do
      let(:mock_repo) { instance_double(IncidentRepo) }
      let(:operation_with_repo) { described_class.new(incident_repo: mock_repo) }
      let!(:incident) do
        create(:incident, :approved,
               race: race,
               race_location: race_location,
               decided_by_user: decider)
      end

      it "uses the injected repository" do
        expected_struct = Structs::Incident.new(
          id: incident.id,
          client_uuid: incident.client_uuid,
          race_id: race.id,
          race_location_id: race_location.id,
          status: "pending",
          description: nil,
          custom_name: nil,
          decided_by_user_id: nil,
          decided_at: nil,
          created_at: incident.created_at,
          updated_at: incident.updated_at,
          race_location_name: race_location.name,
          decided_by_user_name: nil,
          reports_count: 0,
          penalties_count: 0
        )

        allow(mock_repo).to receive(:find).with(incident.id).and_return(expected_struct)

        result = operation_with_repo.call(id: incident.id)

        expect(result).to be_success
        expect(mock_repo).to have_received(:find).with(incident.id)
      end
    end
  end
end
