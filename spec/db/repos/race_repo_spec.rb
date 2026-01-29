# frozen_string_literal: true

require "rails_helper"

RSpec.describe RaceRepo do
  subject(:repo) { described_class.new }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }

  describe "#find" do
    let!(:race) { create(:race, competition: competition, race_type: race_type) }

    it "returns a Structs::Race when found" do
      result = repo.find(race.id)
      
      expect(result).to be_a(Structs::Race)
      expect(result.id).to eq(race.id)
      expect(result.name).to eq(race.name)
    end

    it "returns nil when not found" do
      result = repo.find(999999)
      
      expect(result).to be_nil
    end

    it "includes race_type_name from association" do
      result = repo.find(race.id)
      
      expect(result.race_type_name).to eq(race_type.name)
    end

    it "includes competition_name from association" do
      result = repo.find(race.id)
      
      expect(result.competition_name).to eq(competition.name)
    end
  end

  describe "#find!" do
    let!(:race) { create(:race, competition: competition, race_type: race_type) }

    it "returns a Structs::Race when found" do
      result = repo.find!(race.id)
      
      expect(result).to be_a(Structs::Race)
      expect(result.id).to eq(race.id)
    end

    it "raises ActiveRecord::RecordNotFound when not found" do
      expect { repo.find!(999999) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#find_by" do
    let!(:race) { create(:race, competition: competition, race_type: race_type, name: "Sprint Final") }

    it "finds race by attributes" do
      result = repo.find_by(name: "Sprint Final")
      
      expect(result).to be_a(Structs::Race)
      expect(result.id).to eq(race.id)
    end

    it "returns nil when not found" do
      result = repo.find_by(name: "Nonexistent")
      
      expect(result).to be_nil
    end
  end

  describe "#create" do
    it "creates a race and returns Structs::Race" do
      attrs = {
        competition_id: competition.id,
        race_type_id: race_type.id,
        name: "Women's Sprint - Qualification",
        stage_type: "Qualification",
        stage_name: "Qualification",
        heat_number: nil,
        position: 0,
        status: "scheduled"
      }

      result = repo.create(attrs)

      expect(result).to be_a(Structs::Race)
      expect(result.name).to eq("Women's Sprint - Qualification")
      expect(result.stage_type).to eq("Qualification")
      expect(result.stage_name).to eq("Qualification")
      expect(result.heat_number).to be_nil
      expect(result.status).to eq("scheduled")
    end

    it "persists the race to database" do
      attrs = {
        competition_id: competition.id,
        race_type_id: race_type.id,
        name: "Test Race",
        stage_type: "Final",
        stage_name: "Final",
        position: 0
      }

      expect { repo.create(attrs) }.to change(Race, :count).by(1)
    end

    it "includes associations in returned struct" do
      attrs = {
        competition_id: competition.id,
        race_type_id: race_type.id,
        name: "Test Race",
        stage_type: "Final",
        stage_name: "Final",
        position: 0
      }

      result = repo.create(attrs)

      expect(result.race_type_name).to eq(race_type.name)
      expect(result.competition_name).to eq(competition.name)
    end
  end

  describe "#update" do
    let!(:race) { create(:race, competition: competition, race_type: race_type, name: "Original Name") }

    it "updates the race and returns Structs::Race" do
      result = repo.update(race.id, name: "Updated Name")

      expect(result).to be_a(Structs::Race)
      expect(result.name).to eq("Updated Name")
    end

    it "persists changes to database" do
      repo.update(race.id, name: "Updated Name", status: "in_progress")

      race.reload
      expect(race.name).to eq("Updated Name")
      expect(race.status).to eq("in_progress")
    end

    it "can update stage information" do
      result = repo.update(race.id, stage_type: "Semifinal", heat_number: 2, stage_name: "Semifinal 2")

      expect(result.stage_type).to eq("Semifinal")
      expect(result.heat_number).to eq(2)
      expect(result.stage_name).to eq("Semifinal 2")
    end
  end

  describe "#delete" do
    let!(:race) { create(:race, competition: competition, race_type: race_type) }

    it "deletes the race and returns true" do
      result = repo.delete(race.id)

      expect(result).to be true
      expect { Race.find(race.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "removes race from database" do
      expect { repo.delete(race.id) }.to change(Race, :count).by(-1)
    end

    it "raises error when race not found" do
      expect { repo.delete(999999) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#for_competition" do
    let(:other_competition) { create(:competition) }
    let!(:race1) { create(:race, competition: competition, race_type: race_type, name: "Race 1", position: 0) }
    let!(:race2) { create(:race, competition: competition, race_type: race_type, name: "Race 2", position: 1) }
    let!(:other_race) { create(:race, competition: other_competition, race_type: race_type) }

    it "returns races for specific competition" do
      results = repo.for_competition(competition.id)

      expect(results).to all(be_a(Structs::RaceSummary))
      expect(results.map(&:id)).to contain_exactly(race1.id, race2.id)
    end

    it "orders races by race_type_id, position, scheduled_at" do
      results = repo.for_competition(competition.id)

      expect(results.first.id).to eq(race1.id)
      expect(results.last.id).to eq(race2.id)
    end

    it "returns empty array when no races found" do
      new_competition = create(:competition)
      results = repo.for_competition(new_competition.id)

      expect(results).to be_empty
    end
  end

  describe "#by_race_type" do
    let(:other_race_type) { create(:race_type_individual) }
    let!(:sprint_race1) { create(:race, competition: competition, race_type: race_type, position: 0) }
    let!(:sprint_race2) { create(:race, competition: competition, race_type: race_type, position: 1) }
    let!(:individual_race) { create(:race, competition: competition, race_type: other_race_type) }

    it "returns races for specific race type within competition" do
      results = repo.by_race_type(competition.id, race_type.id)

      expect(results).to all(be_a(Structs::RaceSummary))
      expect(results.map(&:id)).to contain_exactly(sprint_race1.id, sprint_race2.id)
    end

    it "orders by position and scheduled_at" do
      results = repo.by_race_type(competition.id, race_type.id)

      expect(results.first.id).to eq(sprint_race1.id)
      expect(results.last.id).to eq(sprint_race2.id)
    end
  end

  describe "#scheduled" do
    let!(:scheduled_race) { create(:race, :scheduled, competition: competition, race_type: race_type) }
    let!(:in_progress_race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
    let!(:completed_race) { create(:race, :completed, competition: competition, race_type: race_type) }

    it "returns only scheduled races" do
      results = repo.scheduled

      expect(results).to all(be_a(Structs::RaceSummary))
      expect(results.map(&:id)).to contain_exactly(scheduled_race.id)
    end

    it "orders by scheduled_at" do
      future_race = create(:race, :scheduled, competition: competition, race_type: race_type, scheduled_at: Time.current + 5.hours)
      near_race = create(:race, :scheduled, competition: competition, race_type: race_type, scheduled_at: Time.current + 1.hour)

      results = repo.scheduled

      expect(results.first.id).to eq(near_race.id)
      expect(results.last.id).to eq(future_race.id)
    end
  end

  describe "#in_progress" do
    let!(:scheduled_race) { create(:race, :scheduled, competition: competition, race_type: race_type) }
    let!(:in_progress_race1) { create(:race, :in_progress, competition: competition, race_type: race_type) }
    let!(:in_progress_race2) { create(:race, :in_progress, competition: competition, race_type: race_type) }

    it "returns only in_progress races" do
      results = repo.in_progress

      expect(results).to all(be_a(Structs::RaceSummary))
      expect(results.map(&:id)).to contain_exactly(in_progress_race1.id, in_progress_race2.id)
    end
  end

  describe "#completed" do
    let!(:scheduled_race) { create(:race, :scheduled, competition: competition, race_type: race_type) }
    let!(:completed_race1) { create(:race, :completed, competition: competition, race_type: race_type) }
    let!(:completed_race2) { create(:race, :completed, competition: competition, race_type: race_type) }

    it "returns only completed races" do
      results = repo.completed

      expect(results).to all(be_a(Structs::RaceSummary))
      expect(results.map(&:id)).to contain_exactly(completed_race1.id, completed_race2.id)
    end

    it "orders by scheduled_at descending (most recent first)" do
      recent_race = create(:race, :completed, competition: competition, race_type: race_type, scheduled_at: Time.current - 1.hour)
      older_race = create(:race, :completed, competition: competition, race_type: race_type, scheduled_at: Time.current - 5.hours)

      results = repo.completed

      expect(results.first.id).to eq(recent_race.id)
    end
  end

  describe "#auto_startable" do
    let!(:future_race) { create(:race, :scheduled, competition: competition, race_type: race_type, scheduled_at: Time.current + 1.hour) }
    let!(:past_scheduled_race) { create(:race, :scheduled, competition: competition, race_type: race_type, scheduled_at: Time.current - 1.hour) }
    let!(:in_progress_race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
    let!(:no_schedule_race) { create(:race, :scheduled, competition: competition, race_type: race_type, scheduled_at: nil) }

    it "returns scheduled races where scheduled_at has passed" do
      results = repo.auto_startable

      expect(results).to all(be_a(Structs::Race))
      expect(results.map(&:id)).to contain_exactly(past_scheduled_race.id)
    end

    it "excludes races without scheduled_at" do
      results = repo.auto_startable

      expect(results.map(&:id)).not_to include(no_schedule_race.id)
    end

    it "excludes future races" do
      results = repo.auto_startable

      expect(results.map(&:id)).not_to include(future_race.id)
    end

    it "excludes already in_progress races" do
      results = repo.auto_startable

      expect(results.map(&:id)).not_to include(in_progress_race.id)
    end
  end

  describe "#auto_completable" do
    let(:past_competition) { create(:competition, end_date: Date.yesterday) }
    let(:current_competition) { create(:competition, end_date: Date.today) }
    let(:future_competition) { create(:competition, end_date: Date.tomorrow) }

    let!(:past_in_progress) { create(:race, :in_progress, competition: past_competition, race_type: race_type) }
    let!(:current_in_progress) { create(:race, :in_progress, competition: current_competition, race_type: race_type) }
    let!(:future_in_progress) { create(:race, :in_progress, competition: future_competition, race_type: race_type) }
    let!(:past_completed) { create(:race, :completed, competition: past_competition, race_type: race_type) }

    it "returns in_progress races where competition ended before today" do
      results = repo.auto_completable

      expect(results).to all(be_a(Structs::Race))
      expect(results.map(&:id)).to contain_exactly(past_in_progress.id)
    end

    it "excludes races from current or future competitions" do
      results = repo.auto_completable

      expect(results.map(&:id)).not_to include(current_in_progress.id)
      expect(results.map(&:id)).not_to include(future_in_progress.id)
    end

    it "excludes already completed races" do
      results = repo.auto_completable

      expect(results.map(&:id)).not_to include(past_completed.id)
    end
  end

  describe "struct vs summary return types" do
    let!(:race) { create(:race, competition: competition, race_type: race_type) }

    it "returns Structs::Race for single record methods" do
      expect(repo.find(race.id)).to be_a(Structs::Race)
      expect(repo.find!(race.id)).to be_a(Structs::Race)
      expect(repo.find_by(id: race.id)).to be_a(Structs::Race)
      expect(repo.create(competition_id: competition.id, race_type_id: race_type.id, name: "Test", stage_type: "Final", stage_name: "Final", position: 0)).to be_a(Structs::Race)
      expect(repo.update(race.id, name: "Updated")).to be_a(Structs::Race)
    end

    it "returns Structs::RaceSummary for collection methods" do
      results = repo.for_competition(competition.id)
      expect(results).to all(be_a(Structs::RaceSummary))

      results = repo.scheduled
      expect(results).to all(be_a(Structs::RaceSummary))

      results = repo.in_progress
      expect(results).to all(be_a(Structs::RaceSummary))

      results = repo.completed
      expect(results).to all(be_a(Structs::RaceSummary))
    end

    it "returns Structs::Race for auto methods (need full data for operations)" do
      past_race = create(:race, :scheduled, competition: competition, race_type: race_type, scheduled_at: Time.current - 1.hour)
      
      results = repo.auto_startable
      expect(results).to all(be_a(Structs::Race))
    end
  end

  describe "performance considerations" do
    it "eager loads associations to avoid N+1 queries" do
      create_list(:race, 3, competition: competition, race_type: race_type)

      # First query fetches races with eager loaded associations
      races = repo.for_competition(competition.id)
      
      # Accessing race_type_name should not trigger additional queries
      # because associations are already loaded
      query_count = 0
      allow(ActiveRecord::Base.connection).to receive(:execute).and_wrap_original do |method, *args|
        query_count += 1 unless args.first.include?("TRANSACTION")
        method.call(*args)
      end

      races.each { |race| race.race_type_name }
      
      # No additional queries should have been made (race_type_name comes from struct)
      expect(query_count).to eq(0)
    end
  end
end