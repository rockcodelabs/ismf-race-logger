# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Incidents::RemoveReports do
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

  let!(:report1) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation1,
           user: user,
           incident: incident,
           status: "confirmed")
  end

  let!(:report2) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation2,
           user: user,
           incident: incident,
           status: "confirmed")
  end

  let!(:report3) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation1,
           user: user,
           incident: incident,
           status: "confirmed")
  end

  describe "#call" do
    context "with valid params" do
      let(:valid_params) do
        {
          incident_id: incident.id,
          report_ids: [report1.id, report2.id]
        }
      end

      it "returns Success with incident struct" do
        result = operation.call(**valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
      end

      it "unlinks the reports from the incident" do
        operation.call(**valid_params)

        expect(report1.reload.incident_id).to be_nil
        expect(report2.reload.incident_id).to be_nil
      end

      it "keeps other reports linked" do
        operation.call(**valid_params)

        expect(report3.reload.incident_id).to eq(incident.id)
      end

      it "resets report status to pending_review" do
        operation.call(**valid_params)

        expect(report1.reload.status).to eq("pending_review")
        expect(report2.reload.status).to eq("pending_review")
      end

      it "updates the reports_count on incident" do
        result = operation.call(**valid_params)

        # Started with 3 reports, removed 2
        expect(result.value!.reports_count).to eq(1)
      end
    end

    context "with single report ID (not array)" do
      let(:single_report_params) do
        {
          incident_id: incident.id,
          report_ids: report1.id
        }
      end

      it "returns Success and unlinks the report" do
        result = operation.call(**single_report_params)

        expect(result).to be_success
        expect(report1.reload.incident_id).to be_nil
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
          report_ids: [report1.id]
        }
      end

      it "returns Failure" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure).to eq(:incident_not_found)
      end

      it "does not unlink any reports" do
        operation.call(**invalid_params)

        expect(report1.reload.incident_id).to eq(incident.id)
      end
    end

    context "with nonexistent report IDs" do
      let(:invalid_params) do
        {
          incident_id: incident.id,
          report_ids: [report1.id, 999_999]
        }
      end

      it "returns Failure with missing IDs" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:reports_not_found)
        expect(result.failure.last).to eq([999_999])
      end

      it "does not unlink any reports (transaction rollback)" do
        operation.call(**invalid_params)

        expect(report1.reload.incident_id).to eq(incident.id)
      end
    end

    context "with reports from OTHER incidents" do
      let!(:other_incident) do
        create(:incident, race: race, race_location: race_location, status: "pending")
      end

      let!(:other_report) do
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
          report_ids: [other_report.id]
        }
      end

      it "returns Failure with not in incident IDs" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:reports_not_in_incident)
        expect(result.failure.last).to eq([other_report.id])
      end

      it "does not change the report's incident" do
        operation.call(**invalid_params)

        expect(other_report.reload.incident_id).to eq(other_incident.id)
      end
    end

    context "with reports not linked to any incident" do
      let!(:pending_report) do
        create(:report,
               race: race,
               race_location: race_location,
               race_participation: participation1,
               user: user,
               incident: nil,
               status: "pending_review")
      end

      let(:invalid_params) do
        {
          incident_id: incident.id,
          report_ids: [pending_report.id]
        }
      end

      it "returns Failure" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:reports_not_in_incident)
      end
    end

    context "removing all reports from incident" do
      let(:remove_all_params) do
        {
          incident_id: incident.id,
          report_ids: [report1.id, report2.id, report3.id]
        }
      end

      it "returns Success with empty incident" do
        result = operation.call(**remove_all_params)

        expect(result).to be_success
        expect(result.value!.reports_count).to eq(0)
      end

      it "keeps the incident in database" do
        operation.call(**remove_all_params)

        expect(Incident.find_by(id: incident.id)).to be_present
      end

      it "unlinks all reports" do
        operation.call(**remove_all_params)

        expect(report1.reload.incident_id).to be_nil
        expect(report2.reload.incident_id).to be_nil
        expect(report3.reload.incident_id).to be_nil
      end
    end
  end
end