# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Incidents::Merge do
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

  let!(:target_incident) do
    create(:incident,
           race: race,
           race_location: race_location,
           status: "pending",
           description: "Target incident description")
  end

  let!(:source_incident) do
    create(:incident,
           race: race,
           race_location: race_location,
           status: "pending",
           description: "Source incident description")
  end

  let!(:target_report1) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation1,
           user: user,
           incident: target_incident,
           status: "confirmed")
  end

  let!(:target_report2) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation2,
           user: user,
           incident: target_incident,
           status: "confirmed")
  end

  let!(:source_report1) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation1,
           user: user,
           incident: source_incident,
           status: "confirmed")
  end

  let!(:source_report2) do
    create(:report,
           race: race,
           race_location: race_location,
           race_participation: participation2,
           user: user,
           incident: source_incident,
           status: "confirmed")
  end

  describe "#call" do
    context "with valid params (merge_descriptions: false)" do
      let(:valid_params) do
        {
          source_incident_id: source_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: false
        }
      end

      it "returns Success with target incident struct" do
        result = operation.call(**valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Incident)
        expect(result.value!.id).to eq(target_incident.id)
      end

      it "moves all reports from source to target" do
        operation.call(**valid_params)

        expect(source_report1.reload.incident_id).to eq(target_incident.id)
        expect(source_report2.reload.incident_id).to eq(target_incident.id)
        expect(target_report1.reload.incident_id).to eq(target_incident.id)
        expect(target_report2.reload.incident_id).to eq(target_incident.id)
      end

      it "deletes the source incident" do
        operation.call(**valid_params)

        expect(Incident.find_by(id: source_incident.id)).to be_nil
      end

      it "updates the reports_count on target incident" do
        result = operation.call(**valid_params)

        # Target had 2 reports, source had 2 reports
        expect(result.value!.reports_count).to eq(4)
      end

      it "does not merge descriptions" do
        operation.call(**valid_params)

        expect(target_incident.reload.description).to eq("Target incident description")
      end

      it "decreases total incident count by 1" do
        expect { operation.call(**valid_params) }.to change(Incident, :count).by(-1)
      end

      it "does not change total report count" do
        expect { operation.call(**valid_params) }.not_to change(Report, :count)
      end
    end

    context "with merge_descriptions: true" do
      let(:merge_descriptions_params) do
        {
          source_incident_id: source_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: true
        }
      end

      it "returns Success" do
        result = operation.call(**merge_descriptions_params)

        expect(result).to be_success
      end

      it "merges both descriptions with separator" do
        operation.call(**merge_descriptions_params)

        expected = "Target incident description\n\n---\n\nSource incident description"
        expect(target_incident.reload.description).to eq(expected)
      end
    end

    context "when target has no description" do
      before { target_incident.update!(description: nil) }

      let(:merge_params) do
        {
          source_incident_id: source_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: true
        }
      end

      it "uses source description" do
        operation.call(**merge_params)

        expect(target_incident.reload.description).to eq("Source incident description")
      end
    end

    context "when source has no description" do
      before { source_incident.update!(description: nil) }

      let(:merge_params) do
        {
          source_incident_id: source_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: true
        }
      end

      it "keeps target description unchanged" do
        operation.call(**merge_params)

        expect(target_incident.reload.description).to eq("Target incident description")
      end
    end

    context "when both have no description" do
      before do
        target_incident.update!(description: nil)
        source_incident.update!(description: nil)
      end

      let(:merge_params) do
        {
          source_incident_id: source_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: true
        }
      end

      it "keeps target description as nil" do
        operation.call(**merge_params)

        expect(target_incident.reload.description).to be_nil
      end
    end

    context "with nonexistent source incident" do
      let(:invalid_params) do
        {
          source_incident_id: 999_999,
          target_incident_id: target_incident.id,
          merge_descriptions: false
        }
      end

      it "returns Failure" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure).to eq(:source_not_found)
      end

      it "does not delete any incidents" do
        expect { operation.call(**invalid_params) }.not_to change(Incident, :count)
      end

      it "does not move any reports" do
        operation.call(**invalid_params)

        expect(source_report1.reload.incident_id).to eq(source_incident.id)
        expect(source_report2.reload.incident_id).to eq(source_incident.id)
      end
    end

    context "with nonexistent target incident" do
      let(:invalid_params) do
        {
          source_incident_id: source_incident.id,
          target_incident_id: 999_999,
          merge_descriptions: false
        }
      end

      it "returns Failure" do
        result = operation.call(**invalid_params)

        expect(result).to be_failure
        expect(result.failure).to eq(:target_not_found)
      end

      it "does not delete any incidents" do
        expect { operation.call(**invalid_params) }.not_to change(Incident, :count)
      end
    end

    context "when trying to merge incident with itself" do
      let(:self_merge_params) do
        {
          source_incident_id: target_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: false
        }
      end

      it "returns Failure" do
        result = operation.call(**self_merge_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:cannot_merge_self)
      end

      it "does not delete the incident" do
        expect { operation.call(**self_merge_params) }.not_to change(Incident, :count)
      end
    end

    context "when incidents belong to different races" do
      let(:other_race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
      let(:other_location) { create(:race_location, race: other_race) }
      let!(:other_incident) do
        create(:incident,
               race: other_race,
               race_location: other_location,
               status: "pending")
      end

      let(:cross_race_params) do
        {
          source_incident_id: other_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: false
        }
      end

      it "returns Failure" do
        result = operation.call(**cross_race_params)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:different_races)
      end

      it "does not merge incidents" do
        expect { operation.call(**cross_race_params) }.not_to change(Incident, :count)
      end

      it "does not move reports" do
        operation.call(**cross_race_params)

        expect(source_report1.reload.incident_id).to eq(source_incident.id)
      end
    end

    context "when source incident has penalties" do
      let!(:penalty) { create(:penalty) }
      let!(:incident_penalty) do
        create(:incident_penalty,
               incident: source_incident,
               penalty: penalty)
      end

      let(:merge_params) do
        {
          source_incident_id: source_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: false
        }
      end

      it "returns Success and deletes source with penalties" do
        result = operation.call(**merge_params)

        expect(result).to be_success
        expect(Incident.find_by(id: source_incident.id)).to be_nil
      end

      it "deletes the source incident's penalties (dependent: :destroy)" do
        operation.call(**merge_params)

        expect(IncidentPenalty.find_by(id: incident_penalty.id)).to be_nil
      end
    end

    context "merging empty source incident" do
      before do
        source_incident.reports.update_all(incident_id: nil)
      end

      let(:empty_source_params) do
        {
          source_incident_id: source_incident.id,
          target_incident_id: target_incident.id,
          merge_descriptions: false
        }
      end

      it "returns Success" do
        result = operation.call(**empty_source_params)

        expect(result).to be_success
      end

      it "deletes the empty source incident" do
        operation.call(**empty_source_params)

        expect(Incident.find_by(id: source_incident.id)).to be_nil
      end

      it "does not change target reports count" do
        result = operation.call(**empty_source_params)

        expect(result.value!.reports_count).to eq(2)
      end
    end
  end
end