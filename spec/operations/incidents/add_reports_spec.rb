# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Incidents::AddReports do
  subject(:operation) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:user) { create(:user) }
  let(:race_location) { create(:race_location, race: race) }
  let(:athlete1) { create(:athlete) }
  let(:athlete2) { create(:athlete) }
  let(:participation1) { create(:race_participation, race: race, athlete: athlete1, bib_number: 42) }
  let(:participation2) { create(:race_participation, race: race, athlete: athlete2, bib_number: 43) }

  let!(:incident) do
    create(:incident, race: race, race_location: race_location, status: "pending")
  end

  let!(:existing_report) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation1,
           user: user,
           incident: incident,
           status: "confirmed")
  end

  let!(:pending_report1) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation1,
           user: user,
           incident: nil,
           status: "pending_review")
  end

  let!(:pending_report2) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation2,
           user: user,
           incident: nil,
           status: "pending_review")
  end

  describe "#call" do
    context "with valid params" do
      let(:valid_params) do
        {
          incident_id: incident.id,
          report_ids: [pending_report1.id, pending_report2.id]
        }
      end

      it "returns Success with incident struct" do
        result = operation.call(**valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
      end

      it "links all reports to the incident" do
        operation.call(**valid_params)

        expect(pending_report1.reload.incident_id).to eq(incident.id)
        expect(pending_report2.reload.incident_id).to eq(incident.id)
      end

      it "updates the reports_count on incident" do
        result = operation.call(**valid_params)

        # Started with 1 report, added 2 more
        expect(result.value!.reports_count).to eq(3)
      end

      it "does not change report status" do
        operation.call(**valid_params)

        expect(pending_report1.reload.status).to eq("pending_review")
        expect(pending_report2.reload.status).to eq("pending_review")
      end
    end

    context "with single report ID (not array)" do
      let(:single_report_params) do
        {
          incident_id: incident.id,
          report_ids: pending_report1.id
        }
      end

      it "returns Success and links the report" do
        result = operation.call(**single_report_params)

        expect(result).to be_success
        expect(pending_report1.reload.incident_id).to eq(incident.id)
      end
    end

    context "with empty report_ids array" do
      let(:empty_params) do
        {
          incident_id: incident.id,
          report_ids: []
        }
      end

      it "returns Failure" do
        result = operation.call(**empty_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:no_reports_provided)
      end
    end

    context "with nonexistent incident" do
      let(:invalid_params) do
        {
          incident_id: 999_999,
          report_ids: [pending_report1.id]
        }
      end

      it "returns Failure" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure).to eq(:incident_not_found)
      end

      it "does not link any reports" do
        operation.call(**invalid_params)

        expect(pending_report1.reload.incident_id).to be_nil
      end
    end

    context "with nonexistent report IDs" do
      let(:invalid_params) do
        {
          incident_id: incident.id,
          report_ids: [pending_report1.id, 999_999]
        }
      end

      it "returns Failure with missing IDs" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:reports_not_found)
        expect(result.failure.last).to eq([999_999])
      end

      it "does not link any reports (transaction rollback)" do
        operation.call(**invalid_params)

        expect(pending_report1.reload.incident_id).to be_nil
      end
    end

    context "with reports already linked to OTHER incidents" do
      let!(:other_incident) do
        create(:incident, race: race, race_location: race_location, status: "pending")
      end

      let!(:linked_report) do
        create(:report,
               race: race,
               race_location: race_location,
               race_participation: participation1,
               user: user,
               incident: other_incident,
               status: "confirmed")
      end

      let(:invalid_params) do
        {
          incident_id: incident.id,
          report_ids: [linked_report.id]
        }
      end

      it "returns Failure with already linked IDs" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:reports_already_linked)
        expect(result.failure.last).to eq([linked_report.id])
      end

      it "does not change the report's incident" do
        operation.call(**invalid_params)

        expect(linked_report.reload.incident_id).to eq(other_incident.id)
      end
    end

    context "with reports already in SAME incident" do
      let(:params_with_existing) do
        {
          incident_id: incident.id,
          report_ids: [existing_report.id, pending_report1.id]
        }
      end

      it "returns Success (idempotent for reports already in incident)" do
        result = operation.call(**params_with_existing)

        expect(result).to be_success
      end

      it "links the new reports" do
        operation.call(**params_with_existing)

        expect(pending_report1.reload.incident_id).to eq(incident.id)
      end

      it "keeps existing reports linked" do
        operation.call(**params_with_existing)

        expect(existing_report.reload.incident_id).to eq(incident.id)
      end
    end

    context "with reports from different races" do
      let(:other_race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
      let(:other_location) { create(:race_location, race: other_race) }
      let(:other_participation) { create(:race_participation, race: other_race) }
      let!(:other_race_report) do
        create(:report,
               race: other_race,
               race_location: other_location,
               race_participation: other_participation,
               user: user,
               incident: nil,
               status: "pending_review")
      end

      let(:cross_race_params) do
        {
          incident_id: incident.id,
          report_ids: [pending_report1.id, other_race_report.id]
        }
      end

      it "allows adding reports from different races (VAR decision)" do
        result = operation.call(**cross_race_params)

        # This should succeed - VAR knows what they're doing
        expect(result).to be_success
        expect(other_race_report.reload.incident_id).to eq(incident.id)
      end
    end
  end
end