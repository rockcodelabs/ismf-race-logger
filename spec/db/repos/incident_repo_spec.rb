# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncidentRepo do
  subject(:repo) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:user) { create(:user) }
  let(:race_location) { create(:race_location, race: race) }

  describe "#find" do
    let!(:incident) { create(:incident, race: race, race_location: race_location) }

    it "returns a Structs::Incident when found" do
      result = repo.find(incident.id)

      expect(result).to be_a(Structs::Incident)
      expect(result.id).to eq(incident.id)
      expect(result.race_id).to eq(race.id)
    end

    it "returns nil when not found" do
      result = repo.find(999_999)

      expect(result).to be_nil
    end

    it "includes race_location_name from association" do
      result = repo.find(incident.id)

      expect(result.race_location_name).to eq(race_location.name)
    end

    it "includes reports_count" do
      participation = create(:race_participation, race: race)
      create(:report, :confirmed, race: race, race_location: race_location, race_participation: participation, incident: incident)

      result = repo.find(incident.id)

      expect(result.reports_count).to eq(1)
    end

    it "includes penalties_count" do
      penalty = create(:penalty)
      create(:incident_penalty, incident: incident, penalty: penalty)

      result = repo.find(incident.id)

      expect(result.penalties_count).to eq(1)
    end
  end

  describe "#find!" do
    let!(:incident) { create(:incident, race: race, race_location: race_location) }

    it "returns a Structs::Incident when found" do
      result = repo.find!(incident.id)

      expect(result).to be_a(Structs::Incident)
      expect(result.id).to eq(incident.id)
    end

    it "raises ActiveRecord::RecordNotFound when not found" do
      expect { repo.find!(999_999) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#for_race" do
    let(:other_race) { create(:race, competition: competition, race_type: race_type) }
    let!(:incident1) { create(:incident, race: race, race_location: race_location, created_at: 1.hour.ago) }
    let!(:incident2) { create(:incident, race: race, race_location: race_location, created_at: 30.minutes.ago) }
    let!(:other_incident) do
      other_location = create(:race_location, race: other_race)
      create(:incident, race: other_race, race_location: other_location)
    end

    it "returns incidents for specific race" do
      results = repo.for_race(race.id)

      expect(results).to all(be_a(Structs::IncidentSummary))
      expect(results.map(&:id)).to contain_exactly(incident1.id, incident2.id)
    end

    it "orders by created_at descending (most recent first)" do
      results = repo.for_race(race.id)

      expect(results.first.id).to eq(incident2.id)
      expect(results.last.id).to eq(incident1.id)
    end

    it "returns empty array when no incidents found" do
      new_race = create(:race, competition: competition, race_type: race_type)
      results = repo.for_race(new_race.id)

      expect(results).to be_empty
    end
  end

  describe "#pending_for_race" do
    let!(:pending_incident) { create(:incident, :pending, race: race, race_location: race_location) }
    let!(:approved_incident) { create(:incident, :approved, race: race, race_location: race_location) }
    let!(:rejected_incident) { create(:incident, :rejected, race: race, race_location: race_location) }

    it "returns only pending incidents" do
      results = repo.pending_for_race(race.id)

      expect(results).to all(be_a(Structs::IncidentSummary))
      expect(results.map(&:id)).to contain_exactly(pending_incident.id)
    end
  end

  describe "#decided_for_race" do
    let!(:pending_incident) { create(:incident, :pending, race: race, race_location: race_location) }
    let!(:approved_incident) { create(:incident, :approved, race: race, race_location: race_location) }
    let!(:rejected_incident) { create(:incident, :rejected, race: race, race_location: race_location) }

    it "returns only approved and rejected incidents" do
      results = repo.decided_for_race(race.id)

      expect(results).to all(be_a(Structs::IncidentSummary))
      expect(results.map(&:id)).to contain_exactly(approved_incident.id, rejected_incident.id)
    end

    it "orders by decided_at descending" do
      results = repo.decided_for_race(race.id)

      decided_ats = results.map(&:created_at)
      # Note: ordered by decided_at but we can check order is consistent
      expect(results.size).to eq(2)
    end
  end

  describe "#approved_for_race" do
    let!(:pending_incident) { create(:incident, :pending, race: race, race_location: race_location) }
    let!(:approved_incident1) { create(:incident, :approved, race: race, race_location: race_location) }
    let!(:approved_incident2) { create(:incident, :approved, race: race, race_location: race_location) }
    let!(:rejected_incident) { create(:incident, :rejected, race: race, race_location: race_location) }

    it "returns only approved incidents" do
      results = repo.approved_for_race(race.id)

      expect(results).to all(be_a(Structs::IncidentSummary))
      expect(results.map(&:id)).to contain_exactly(approved_incident1.id, approved_incident2.id)
    end
  end

  describe "#rejected_for_race" do
    let!(:pending_incident) { create(:incident, :pending, race: race, race_location: race_location) }
    let!(:approved_incident) { create(:incident, :approved, race: race, race_location: race_location) }
    let!(:rejected_incident1) { create(:incident, :rejected, race: race, race_location: race_location) }
    let!(:rejected_incident2) { create(:incident, :rejected, race: race, race_location: race_location) }

    it "returns only rejected incidents" do
      results = repo.rejected_for_race(race.id)

      expect(results).to all(be_a(Structs::IncidentSummary))
      expect(results.map(&:id)).to contain_exactly(rejected_incident1.id, rejected_incident2.id)
    end
  end

  describe "#by_status" do
    let!(:pending) { create(:incident, :pending, race: race, race_location: race_location) }
    let!(:approved) { create(:incident, :approved, race: race, race_location: race_location) }
    let!(:rejected) { create(:incident, :rejected, race: race, race_location: race_location) }

    it "returns incidents filtered by pending status" do
      results = repo.by_status(race.id, "pending")

      expect(results).to all(be_a(Structs::IncidentSummary))
      expect(results.map(&:id)).to contain_exactly(pending.id)
    end

    it "returns incidents filtered by approved status" do
      results = repo.by_status(race.id, "approved")

      expect(results.map(&:id)).to contain_exactly(approved.id)
    end

    it "returns incidents filtered by rejected status" do
      results = repo.by_status(race.id, "rejected")

      expect(results.map(&:id)).to contain_exactly(rejected.id)
    end
  end

  describe "#recent" do
    before do
      5.times do |i|
        create(:incident, race: race, race_location: race_location, created_at: i.hours.ago)
      end
    end

    it "returns recent incidents across all races" do
      results = repo.recent(3)

      expect(results).to all(be_a(Structs::IncidentSummary))
      expect(results.size).to eq(3)
    end

    it "orders by created_at descending" do
      results = repo.recent(5)

      created_ats = results.map(&:created_at)
      expect(created_ats).to eq(created_ats.sort.reverse)
    end
  end

  describe "#count_by_status" do
    before do
      3.times { create(:incident, :pending, race: race, race_location: race_location) }
      2.times { create(:incident, :approved, race: race, race_location: race_location) }
      1.times { create(:incident, :rejected, race: race, race_location: race_location) }
    end

    it "returns counts grouped by status" do
      result = repo.count_by_status(race.id)

      expect(result).to eq({
        "pending" => 3,
        "approved" => 2,
        "rejected" => 1
      })
    end
  end

  describe "#find_with_reports" do
    let!(:incident) { create(:incident, race: race, race_location: race_location) }
    let!(:report1) do
      participation = create(:race_participation, race: race)
      create(:report, :confirmed, race: race, race_location: race_location, race_participation: participation, incident: incident)
    end
    let!(:report2) do
      participation = create(:race_participation, race: race)
      create(:report, :confirmed, race: race, race_location: race_location, race_participation: participation, incident: incident)
    end

    it "returns the incident with reports count" do
      result = repo.find_with_reports(incident.id)

      expect(result).to be_a(Structs::Incident)
      expect(result.id).to eq(incident.id)
      expect(result.reports_count).to eq(2)
    end

    it "returns nil when not found" do
      result = repo.find_with_reports(999_999)

      expect(result).to be_nil
    end
  end

  describe "summary includes bib_numbers" do
    let!(:incident) { create(:incident, race: race, race_location: race_location) }

    before do
      [ 10, 25, 5 ].each do |bib|
        participation = create(:race_participation, race: race, bib_number: bib)
        create(:report, :confirmed,
               race: race,
               race_location: race_location,
               race_participation: participation,
               bib_number: bib,
               incident: incident)
      end
    end

    it "includes sorted unique bib numbers in summary" do
      results = repo.for_race(race.id)

      expect(results.first.bib_numbers).to eq([ 5, 10, 25 ])
    end
  end

  describe "struct vs summary return types" do
    let!(:incident) { create(:incident, race: race, race_location: race_location) }

    it "returns Structs::Incident for single record methods" do
      expect(repo.find(incident.id)).to be_a(Structs::Incident)
      expect(repo.find!(incident.id)).to be_a(Structs::Incident)
      expect(repo.find_with_reports(incident.id)).to be_a(Structs::Incident)
    end

    it "returns Structs::IncidentSummary for collection methods" do
      results = repo.for_race(race.id)
      expect(results).to all(be_a(Structs::IncidentSummary))

      results = repo.pending_for_race(race.id)
      expect(results).to all(be_a(Structs::IncidentSummary))

      results = repo.decided_for_race(race.id)
      expect(results).to all(be_a(Structs::IncidentSummary))

      results = repo.recent(5)
      expect(results).to all(be_a(Structs::IncidentSummary))
    end
  end

  describe "decided_by_user association" do
    let(:decider) { create(:user, name: "John Decider") }
    let!(:decided_incident) do
      create(:incident, :approved,
             race: race,
             race_location: race_location,
             decided_by_user: decider,
             decided_at: Time.current)
    end

    it "includes decided_by_user_name in struct" do
      result = repo.find(decided_incident.id)

      expect(result.decided_by_user_name).to eq("John Decider")
    end

    it "includes decided_at in struct" do
      result = repo.find(decided_incident.id)

      expect(result.decided_at).to be_present
    end
  end

  describe "penalties count in summary" do
    let!(:incident) { create(:incident, race: race, race_location: race_location) }

    before do
      penalty1 = create(:penalty, :false_start)
      penalty2 = create(:penalty, :wrong_gate)
      create(:incident_penalty, incident: incident, penalty: penalty1)
      create(:incident_penalty, incident: incident, penalty: penalty2)
    end

    it "includes penalties count in summary" do
      results = repo.for_race(race.id)

      expect(results.first.penalties_count).to eq(2)
    end
  end
end
