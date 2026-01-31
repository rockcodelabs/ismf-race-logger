# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Incidents::Create do
  subject(:operation) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:user) { create(:user) }
  let(:race_location) { create(:race_location, race: race) }

  describe "#call" do
    context "with valid params and single confirmed report" do
      let(:participation) { create(:race_participation, race: race) }
      let!(:confirmed_report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation,
               incident: nil)
      end

      let(:valid_params) do
        {
          report_ids: [ confirmed_report.id ]
        }
      end

      it "returns Success with an incident struct" do
        result = operation.call(valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
      end

      it "creates an incident in the database" do
        expect { operation.call(valid_params) }.to change(Incident, :count).by(1)
      end

      it "sets the status to pending" do
        result = operation.call(valid_params)

        expect(result.value!.status).to eq("pending")
      end

      it "links the report to the incident" do
        result = operation.call(valid_params)

        confirmed_report.reload
        expect(confirmed_report.incident_id).to eq(result.value!.id)
      end

      it "sets race_id from the report" do
        result = operation.call(valid_params)

        expect(result.value!.race_id).to eq(race.id)
      end

      it "sets race_location_id from the report" do
        result = operation.call(valid_params)

        expect(result.value!.race_location_id).to eq(race_location.id)
      end

      it "generates a client_uuid" do
        result = operation.call(valid_params)

        expect(result.value!.client_uuid).to be_present
        expect(result.value!.client_uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      end

      it "includes reports_count in the returned struct" do
        result = operation.call(valid_params)

        expect(result.value!.reports_count).to eq(1)
      end
    end

    context "with multiple confirmed reports" do
      let(:participation1) { create(:race_participation, race: race, bib_number: 10) }
      let(:participation2) { create(:race_participation, race: race, bib_number: 20) }
      let(:participation3) { create(:race_participation, race: race, bib_number: 30) }

      let!(:report1) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation1,
               bib_number: 10,
               incident: nil)
      end
      let!(:report2) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation2,
               bib_number: 20,
               incident: nil)
      end
      let!(:report3) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation3,
               bib_number: 30,
               incident: nil)
      end

      let(:valid_params) do
        {
          report_ids: [ report1.id, report2.id, report3.id ]
        }
      end

      it "creates a single incident for all reports" do
        expect { operation.call(valid_params) }.to change(Incident, :count).by(1)
      end

      it "links all reports to the incident" do
        result = operation.call(valid_params)
        incident_id = result.value!.id

        [ report1, report2, report3 ].each do |report|
          report.reload
          expect(report.incident_id).to eq(incident_id)
        end
      end

      it "includes correct reports_count" do
        result = operation.call(valid_params)

        expect(result.value!.reports_count).to eq(3)
      end
    end

    context "with optional description" do
      let(:participation) { create(:race_participation, race: race) }
      let!(:confirmed_report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation,
               incident: nil)
      end

      let(:params_with_description) do
        {
          report_ids: [ confirmed_report.id ],
          description: "Multiple observers saw the same infraction"
        }
      end

      it "stores the description" do
        result = operation.call(params_with_description)

        expect(result.value!.description).to eq("Multiple observers saw the same infraction")
      end
    end

    context "with custom race_location_id" do
      let(:participation) { create(:race_participation, race: race) }
      let(:other_location) { create(:race_location, race: race, name: "Custom Location") }
      let!(:confirmed_report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation,
               incident: nil)
      end

      let(:params_with_location) do
        {
          report_ids: [ confirmed_report.id ],
          race_location_id: other_location.id
        }
      end

      it "uses the provided race_location_id" do
        result = operation.call(params_with_location)

        expect(result.value!.race_location_id).to eq(other_location.id)
      end
    end

    context "with empty report_ids" do
      let(:invalid_params) do
        {
          report_ids: []
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:report_ids]).to be_present
      end

      it "does not create an incident" do
        expect { operation.call(invalid_params) }.not_to change(Incident, :count)
      end
    end

    context "with missing report_ids" do
      let(:invalid_params) { {} }

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
      end
    end

    context "with nonexistent report_ids" do
      let(:invalid_params) do
        {
          report_ids: [ 999_999, 999_998 ]
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:report_ids]).to include("one or more reports not found")
      end
    end

    context "with pending_review reports (not confirmed)" do
      let(:participation) { create(:race_participation, race: race) }
      let!(:pending_report) do
        create(:report, :pending_review,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation,
               incident: nil)
      end

      let(:invalid_params) do
        {
          report_ids: [ pending_report.id ]
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:report_ids]).to include("all reports must be confirmed before merging into an incident")
      end

      it "does not create an incident" do
        expect { operation.call(invalid_params) }.not_to change(Incident, :count)
      end
    end

    context "with reports already linked to an incident" do
      let(:participation) { create(:race_participation, race: race) }
      let(:existing_incident) { create(:incident, race: race, race_location: race_location) }
      let!(:linked_report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation,
               incident: existing_incident)
      end

      let(:invalid_params) do
        {
          report_ids: [ linked_report.id ]
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:report_ids]).to include("one or more reports are already linked to an incident")
      end

      it "does not create a new incident" do
        expect { operation.call(invalid_params) }.not_to change(Incident, :count)
      end
    end

    context "with mix of valid and invalid reports" do
      let(:participation1) { create(:race_participation, race: race) }
      let(:participation2) { create(:race_participation, race: race) }
      let!(:confirmed_report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation1,
               incident: nil)
      end
      let!(:pending_report) do
        create(:report, :pending_review,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation2,
               incident: nil)
      end

      let(:invalid_params) do
        {
          report_ids: [ confirmed_report.id, pending_report.id ]
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
      end

      it "does not create an incident" do
        expect { operation.call(invalid_params) }.not_to change(Incident, :count)
      end

      it "does not link any reports" do
        operation.call(invalid_params)

        confirmed_report.reload
        expect(confirmed_report.incident_id).to be_nil
      end
    end

    context "with reports from different races" do
      let(:other_race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
      let(:other_location) { create(:race_location, race: other_race) }
      let(:participation1) { create(:race_participation, race: race) }
      let(:participation2) { create(:race_participation, race: other_race) }

      let!(:report1) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation1,
               incident: nil)
      end
      let!(:report2) do
        create(:report, :confirmed,
               race: other_race,
               user: user,
               race_location: other_location,
               race_participation: participation2,
               incident: nil)
      end

      let(:invalid_params) do
        {
          report_ids: [ report1.id, report2.id ]
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last[:report_ids]).to include("all reports must belong to the same race")
      end
    end

    context "transactional behavior" do
      let(:participation1) { create(:race_participation, race: race) }
      let(:participation2) { create(:race_participation, race: race) }
      let!(:report1) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation1,
               incident: nil)
      end
      let!(:report2) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation2,
               incident: nil)
      end

      it "creates incident and links all reports in a transaction" do
        result = operation.call(report_ids: [ report1.id, report2.id ])

        expect(result).to be_success

        incident_id = result.value!.id
        report1.reload
        report2.reload

        expect(report1.incident_id).to eq(incident_id)
        expect(report2.incident_id).to eq(incident_id)
      end
    end

    context "with custom incident_repo" do
      let(:mock_repo) { instance_double(IncidentRepo) }
      let(:operation_with_repo) { described_class.new(incident_repo: mock_repo) }
      let(:participation) { create(:race_participation, race: race) }
      let!(:confirmed_report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation,
               incident: nil)
      end

      it "uses the injected repository" do
        expected_struct = Structs::Incident.new(
          id: 1,
          client_uuid: SecureRandom.uuid,
          race_id: race.id,
          race_location_id: race_location.id,
          status: "pending",
          description: nil,
          decided_by_user_id: nil,
          decided_at: nil,
          created_at: Time.current,
          updated_at: Time.current,
          race_location_name: race_location.name,
          decided_by_user_name: nil,
          reports_count: 1,
          penalties_count: 0
        )

        allow(mock_repo).to receive(:find).and_return(expected_struct)

        result = operation_with_repo.call(report_ids: [ confirmed_report.id ])

        expect(result).to be_success
        expect(mock_repo).to have_received(:find)
      end
    end
  end
end
