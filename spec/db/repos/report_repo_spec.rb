# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportRepo do
  subject(:repo) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let(:user) { create(:user) }
  let(:race_location) { create(:race_location, race: race) }
  let(:athlete) { create(:athlete) }
  let(:participation) { create(:race_participation, race: race, athlete: athlete) }

  describe "#find" do
    let!(:report) do
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation,
             bib_number: participation.bib_number)
    end

    it "returns a Structs::Report when found" do
      result = repo.find(report.id)

      expect(result).to be_a(Structs::Report)
      expect(result.id).to eq(report.id)
      expect(result.bib_number).to eq(participation.bib_number)
    end

    it "returns nil when not found" do
      result = repo.find(999_999)

      expect(result).to be_nil
    end

    it "includes race_location_name from association" do
      result = repo.find(report.id)

      expect(result.race_location_name).to eq(race_location.name)
    end

    it "includes athlete_name from association" do
      result = repo.find(report.id)

      expect(result.athlete_name).to eq("#{athlete.first_name} #{athlete.last_name}")
    end

    it "includes user_name from association" do
      result = repo.find(report.id)

      expect(result.user_name).to eq(user.display_name)
    end
  end

  describe "#find!" do
    let!(:report) do
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation)
    end

    it "returns a Structs::Report when found" do
      result = repo.find!(report.id)

      expect(result).to be_a(Structs::Report)
      expect(result.id).to eq(report.id)
    end

    it "raises ActiveRecord::RecordNotFound when not found" do
      expect { repo.find!(999_999) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#find_by_client_uuid" do
    let(:client_uuid) { SecureRandom.uuid }
    let!(:report) do
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation,
             client_uuid: client_uuid)
    end

    it "returns a Structs::Report when found" do
      result = repo.find_by_client_uuid(client_uuid)

      expect(result).to be_a(Structs::Report)
      expect(result.id).to eq(report.id)
      expect(result.client_uuid).to eq(client_uuid)
    end

    it "returns nil when not found" do
      result = repo.find_by_client_uuid("nonexistent-uuid")

      expect(result).to be_nil
    end
  end

  describe "#for_race" do
    let(:other_race) { create(:race, competition: competition, race_type: race_type) }
    let!(:report1) do
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation,
             created_at: 1.hour.ago)
    end
    let!(:report2) do
      participation2 = create(:race_participation, race: race)
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation2,
             bib_number: participation2.bib_number,
             created_at: 30.minutes.ago)
    end
    let!(:other_report) do
      other_location = create(:race_location, race: other_race)
      other_participation = create(:race_participation, race: other_race)
      create(:report,
             race: other_race,
             user: user,
             race_location: other_location,
             race_participation: other_participation)
    end

    it "returns reports for specific race" do
      results = repo.for_race(race.id)

      expect(results).to all(be_a(Structs::ReportSummary))
      expect(results.map(&:id)).to contain_exactly(report1.id, report2.id)
    end

    it "orders by created_at descending (most recent first)" do
      results = repo.for_race(race.id)

      expect(results.first.id).to eq(report2.id)
      expect(results.last.id).to eq(report1.id)
    end

    it "returns empty array when no reports found" do
      new_race = create(:race, competition: competition, race_type: race_type)
      results = repo.for_race(new_race.id)

      expect(results).to be_empty
    end
  end

  describe "#pending_for_race" do
    let!(:pending_report) do
      create(:report, :pending_review,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation)
    end
    let!(:confirmed_report) do
      participation2 = create(:race_participation, race: race)
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation2)
    end
    let!(:rejected_report) do
      participation3 = create(:race_participation, race: race)
      create(:report, :rejected,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation3)
    end

    it "returns only pending_review reports" do
      results = repo.pending_for_race(race.id)

      expect(results).to all(be_a(Structs::ReportSummary))
      expect(results.map(&:id)).to contain_exactly(pending_report.id)
    end
  end

  describe "#confirmed_for_race" do
    let!(:pending_report) do
      create(:report, :pending_review,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation)
    end
    let!(:confirmed_report1) do
      participation2 = create(:race_participation, race: race)
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation2)
    end
    let!(:confirmed_report2) do
      participation3 = create(:race_participation, race: race)
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation3)
    end

    it "returns only confirmed reports" do
      results = repo.confirmed_for_race(race.id)

      expect(results).to all(be_a(Structs::ReportSummary))
      expect(results.map(&:id)).to contain_exactly(confirmed_report1.id, confirmed_report2.id)
    end
  end

  describe "#confirmed_without_incident" do
    let(:incident) { create(:incident, race: race, race_location: race_location) }
    let!(:confirmed_no_incident) do
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation,
             incident: nil)
    end
    let!(:confirmed_with_incident) do
      participation2 = create(:race_participation, race: race)
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation2,
             incident: incident)
    end
    let!(:pending_report) do
      participation3 = create(:race_participation, race: race)
      create(:report, :pending_review,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation3)
    end

    it "returns only confirmed reports without incident" do
      results = repo.confirmed_without_incident(race.id)

      expect(results).to all(be_a(Structs::ReportSummary))
      expect(results.map(&:id)).to contain_exactly(confirmed_no_incident.id)
    end
  end

  describe "#for_incident" do
    let(:incident) { create(:incident, race: race, race_location: race_location) }
    let!(:linked_report1) do
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation,
             incident: incident)
    end
    let!(:linked_report2) do
      participation2 = create(:race_participation, race: race)
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation2,
             incident: incident)
    end
    let!(:unlinked_report) do
      participation3 = create(:race_participation, race: race)
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation3,
             incident: nil)
    end

    it "returns only reports for specific incident" do
      results = repo.for_incident(incident.id)

      expect(results).to all(be_a(Structs::ReportSummary))
      expect(results.map(&:id)).to contain_exactly(linked_report1.id, linked_report2.id)
    end

    it "orders by created_at ascending" do
      results = repo.for_incident(incident.id)

      expect(results.first.created_at).to be <= results.last.created_at
    end
  end

  describe "#by_bib" do
    let(:bib_42_participation) { create(:race_participation, race: race, bib_number: 42) }
    let(:bib_99_participation) { create(:race_participation, race: race, bib_number: 99) }

    let!(:bib_42_report1) do
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: bib_42_participation,
             bib_number: 42)
    end
    let!(:bib_42_report2) do
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: bib_42_participation,
             bib_number: 42)
    end
    let!(:bib_99_report) do
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: bib_99_participation,
             bib_number: 99)
    end

    it "returns reports for specific bib number" do
      results = repo.by_bib(race.id, 42)

      expect(results).to all(be_a(Structs::ReportSummary))
      expect(results.map(&:id)).to contain_exactly(bib_42_report1.id, bib_42_report2.id)
    end
  end

  describe "#recent" do
    before do
      5.times do |i|
        p = create(:race_participation, race: race)
        create(:report,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: p,
               created_at: i.hours.ago)
      end
    end

    it "returns recent reports across all races" do
      results = repo.recent(3)

      expect(results).to all(be_a(Structs::ReportSummary))
      expect(results.size).to eq(3)
    end

    it "orders by created_at descending" do
      results = repo.recent(5)

      created_ats = results.map(&:created_at)
      expect(created_ats).to eq(created_ats.sort.reverse)
    end
  end

  describe "#by_status" do
    let!(:pending) do
      create(:report, :pending_review,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation)
    end
    let!(:confirmed) do
      p2 = create(:race_participation, race: race)
      create(:report, :confirmed,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: p2)
    end
    let!(:rejected) do
      p3 = create(:race_participation, race: race)
      create(:report, :rejected,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: p3)
    end

    it "returns reports filtered by status" do
      results = repo.by_status(race.id, "confirmed")

      expect(results).to all(be_a(Structs::ReportSummary))
      expect(results.map(&:id)).to contain_exactly(confirmed.id)
    end
  end

  describe "#count_by_status" do
    before do
      3.times do
        p = create(:race_participation, race: race)
        create(:report, :pending_review,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: p)
      end

      2.times do
        p = create(:race_participation, race: race)
        create(:report, :confirmed,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: p)
      end

      1.times do
        p = create(:race_participation, race: race)
        create(:report, :rejected,
               race: race,
               user: user,
               race_location: race_location,
               race_participation: p)
      end
    end

    it "returns counts grouped by status" do
      result = repo.count_by_status(race.id)

      expect(result).to eq({
        "pending_review" => 3,
        "confirmed" => 2,
        "rejected" => 1
      })
    end
  end

  describe "struct vs summary return types" do
    let!(:report) do
      create(:report,
             race: race,
             user: user,
             race_location: race_location,
             race_participation: participation)
    end

    it "returns Structs::Report for single record methods" do
      expect(repo.find(report.id)).to be_a(Structs::Report)
      expect(repo.find!(report.id)).to be_a(Structs::Report)
      expect(repo.find_by_client_uuid(report.client_uuid)).to be_a(Structs::Report)
    end

    it "returns Structs::ReportSummary for collection methods" do
      results = repo.for_race(race.id)
      expect(results).to all(be_a(Structs::ReportSummary))

      results = repo.pending_for_race(race.id)
      expect(results).to all(be_a(Structs::ReportSummary))

      results = repo.confirmed_for_race(race.id)
      # May be empty, but if not empty, should be summaries
    end
  end
end
