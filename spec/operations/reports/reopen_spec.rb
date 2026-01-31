# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Reports::Reopen do
  subject(:operation) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:user) { create(:user) }
  let(:race_location) { create(:race_location, race: race) }
  let(:athlete) { create(:athlete) }
  let(:participation) { create(:race_participation, race: race, athlete: athlete) }

  describe "#call" do
    context "with a confirmed report" do
      let!(:report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation)
      end

      it "returns Success with a report struct" do
        result = operation.call(id: report.id)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Report)
      end

      it "updates the status to pending_review" do
        result = operation.call(id: report.id)

        expect(result.value!.status).to eq("pending_review")
      end

      it "persists the status change to the database" do
        operation.call(id: report.id)

        report.reload
        expect(report.status).to eq("pending_review")
      end

      it "returns the report with all associations" do
        result = operation.call(id: report.id)

        returned_report = result.value!
        expect(returned_report.id).to eq(report.id)
        expect(returned_report.race_id).to eq(race.id)
        expect(returned_report.race_location_name).to eq(race_location.name)
        expect(returned_report.athlete_name).to eq("#{athlete.first_name} #{athlete.last_name}")
      end
    end

    context "with a rejected report" do
      let!(:report) do
        create(:report, :rejected,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation)
      end

      it "returns Success with a report struct" do
        result = operation.call(id: report.id)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Report)
      end

      it "updates the status to pending_review" do
        result = operation.call(id: report.id)

        expect(result.value!.status).to eq("pending_review")
      end

      it "persists the status change to the database" do
        operation.call(id: report.id)

        report.reload
        expect(report.status).to eq("pending_review")
      end
    end

    context "with an already pending_review report" do
      let!(:report) do
        create(:report, :pending_review,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation)
      end

      it "returns Failure with already_pending error" do
        result = operation.call(id: report.id)

        expect(result).to be_failure
        expect(result.failure).to eq(:already_pending)
      end

      it "does not change the report status" do
        operation.call(id: report.id)

        report.reload
        expect(report.status).to eq("pending_review")
      end
    end

    context "with nonexistent report" do
      it "returns Failure with not_found error" do
        result = operation.call(id: 999_999)

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end
    end

    context "with a confirmed report linked to an incident" do
      let(:incident) { create(:incident, race: race, race_location: race_location) }
      let!(:report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation,
               incident: incident)
      end

      it "reopens the report and removes incident link" do
        result = operation.call(id: report.id)

        expect(result).to be_success
        expect(result.value!.status).to eq("pending_review")
      end

      it "clears the incident_id from the report" do
        operation.call(id: report.id)

        report.reload
        expect(report.incident_id).to be_nil
      end
    end

    context "reopening multiple reports" do
      let!(:report1) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation)
      end
      let!(:report2) do
        participation2 = create(:race_participation, race: race)
        create(:report, :rejected,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation2)
      end

      it "reopens each report independently" do
        result1 = operation.call(id: report1.id)
        result2 = operation.call(id: report2.id)

        expect(result1).to be_success
        expect(result2).to be_success
        expect(result1.value!.status).to eq("pending_review")
        expect(result2.value!.status).to eq("pending_review")
      end
    end

    context "with custom report_repo" do
      let(:mock_repo) { instance_double(ReportRepo) }
      let(:operation_with_repo) { described_class.new(report_repo: mock_repo) }
      let!(:report) do
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: participation)
      end

      it "uses the injected repository" do
        expected_struct = Structs::Report.new(
          id: report.id,
          client_uuid: report.client_uuid,
          race_id: race.id,
          incident_id: nil,
          user_id: user.id,
          race_location_id: race_location.id,
          race_participation_id: participation.id,
          bib_number: participation.bib_number,
          athlete_position: nil,
          description: nil,
          status: "pending_review",
          created_at: report.created_at,
          updated_at: report.updated_at,
          race_location_name: race_location.name,
          athlete_name: "#{athlete.first_name} #{athlete.last_name}",
          user_name: user.display_name
        )

        allow(mock_repo).to receive(:find).with(report.id).and_return(expected_struct)

        result = operation_with_repo.call(id: report.id)

        expect(result).to be_success
        expect(mock_repo).to have_received(:find).with(report.id)
      end
    end
  end
end
