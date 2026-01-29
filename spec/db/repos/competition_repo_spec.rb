# frozen_string_literal: true

require "rails_helper"

RSpec.describe CompetitionRepo do
  subject(:repo) { described_class.new }

  describe "configuration" do
    it "has correct record_class" do
      expect(described_class.record_class).to eq(Competition)
    end

    it "has correct struct_class" do
      expect(described_class.struct_class).to eq(Structs::Competition)
    end

    it "has correct summary_class" do
      expect(described_class.summary_class).to eq(Structs::CompetitionSummary)
    end
  end

  describe "#find" do
    context "when competition exists" do
      let!(:competition) { create(:competition, :verbier) }

      it "returns a Structs::Competition" do
        result = repo.find(competition.id)

        expect(result).to be_a(Structs::Competition)
        expect(result.id).to eq(competition.id)
        expect(result.name).to eq("World Cup Verbier 2024")
        expect(result.city).to eq("Verbier")
      end

      it "includes logo_url when logo is attached" do
        competition.logo.attach(
          io: StringIO.new("fake image data"),
          filename: "logo.png",
          content_type: "image/png"
        )

        result = repo.find(competition.id)

        expect(result.logo_url).to be_present
        expect(result.logo_url).to include("logo.png")
      end

      it "has nil logo_url when no logo is attached" do
        result = repo.find(competition.id)

        expect(result.logo_url).to be_nil
      end
    end

    context "when competition does not exist" do
      it "returns nil" do
        result = repo.find(999999)

        expect(result).to be_nil
      end
    end
  end

  describe "#find!" do
    context "when competition exists" do
      let!(:competition) { create(:competition) }

      it "returns a Structs::Competition" do
        result = repo.find!(competition.id)

        expect(result).to be_a(Structs::Competition)
        expect(result.id).to eq(competition.id)
      end
    end

    context "when competition does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { repo.find!(999999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#all" do
    let!(:comp1) { create(:competition, start_date: Date.current + 10.days) }
    let!(:comp2) { create(:competition, start_date: Date.current + 20.days) }
    let!(:comp3) { create(:competition, start_date: Date.current + 5.days) }

    it "returns an array of Structs::CompetitionSummary" do
      result = repo.all

      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
      expect(result).to all(be_a(Structs::CompetitionSummary))
    end

    it "orders by start_date desc" do
      result = repo.all

      expect(result.map(&:id)).to eq([comp2.id, comp1.id, comp3.id])
    end
  end

  describe "#ongoing" do
    let!(:ongoing1) { create(:competition, start_date: Date.current - 1.day, end_date: Date.current + 1.day) }
    let!(:ongoing2) { create(:competition, start_date: Date.current - 2.days, end_date: Date.current) }
    let!(:upcoming) { create(:competition, :upcoming) }
    let!(:past) { create(:competition, :past) }

    it "returns only ongoing competitions" do
      result = repo.ongoing

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::CompetitionSummary))
      expect(result.map(&:id)).to contain_exactly(ongoing1.id, ongoing2.id)
    end

    it "orders by start_date desc" do
      result = repo.ongoing

      # ongoing1 has start_date -1 day (more recent), ongoing2 has -2 days (older)
      # DESC order puts most recent first
      expect(result.first.id).to eq(ongoing1.id)
      expect(result.last.id).to eq(ongoing2.id)
    end
  end

  describe "#upcoming" do
    let!(:upcoming1) { create(:competition, start_date: Date.current + 10.days, end_date: Date.current + 12.days) }
    let!(:upcoming2) { create(:competition, start_date: Date.current + 5.days, end_date: Date.current + 7.days) }
    let!(:ongoing) { create(:competition, :ongoing) }
    let!(:past) { create(:competition, :past) }

    it "returns only upcoming competitions" do
      result = repo.upcoming

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::CompetitionSummary))
      expect(result.map(&:id)).to contain_exactly(upcoming1.id, upcoming2.id)
    end

    it "orders by start_date asc (soonest first)" do
      result = repo.upcoming

      # upcoming2 has start_date +5 days (sooner), upcoming1 has +10 days (later)
      # ASC order puts soonest first
      expect(result.first.id).to eq(upcoming2.id)
      expect(result.last.id).to eq(upcoming1.id)
    end
  end

  describe "#past" do
    let!(:past1) { create(:competition, start_date: Date.current - 10.days, end_date: Date.current - 8.days) }
    let!(:past2) { create(:competition, start_date: Date.current - 20.days, end_date: Date.current - 18.days) }
    let!(:ongoing) { create(:competition, :ongoing) }
    let!(:upcoming) { create(:competition, :upcoming) }

    it "returns only past competitions" do
      result = repo.past

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::CompetitionSummary))
      expect(result.map(&:id)).to contain_exactly(past1.id, past2.id)
    end

    it "orders by start_date desc (most recent first)" do
      result = repo.past

      expect(result.first.id).to eq(past1.id)
      expect(result.last.id).to eq(past2.id)
    end
  end

  describe "#by_country" do
    let!(:swiss1) { create(:competition, country: "CHE") }
    let!(:swiss2) { create(:competition, country: "CHE") }
    let!(:italian) { create(:competition, country: "ITA") }

    it "returns competitions for the specified country" do
      result = repo.by_country("CHE")

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::CompetitionSummary))
      expect(result.map(&:id)).to contain_exactly(swiss1.id, swiss2.id)
    end

    it "returns empty array for country with no competitions" do
      result = repo.by_country("FRA")

      expect(result).to be_empty
    end
  end

  describe "#by_city" do
    let!(:verbier1) { create(:competition, city: "Verbier") }
    let!(:verbier2) { create(:competition, city: "Verbier") }
    let!(:madonna) { create(:competition, city: "Madonna di Campiglio") }

    it "returns competitions for the specified city (case-insensitive)" do
      result = repo.by_city("verbier")

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::CompetitionSummary))
      expect(result.map(&:id)).to contain_exactly(verbier1.id, verbier2.id)
    end

    it "returns empty array for city with no competitions" do
      result = repo.by_city("Paris")

      expect(result).to be_empty
    end
  end

  describe "#search" do
    let!(:verbier) { create(:competition, name: "World Cup Verbier 2024", city: "Verbier", place: "Swiss Alps") }
    let!(:madonna) { create(:competition, name: "World Cup Madonna 2024", city: "Madonna di Campiglio", place: "Trentino") }
    let!(:andorra) { create(:competition, name: "World Cup Andorra 2024", city: "Ordino", place: "Pyrenees") }

    it "finds competitions by name (case-insensitive)" do
      result = repo.search("verbier")

      expect(result.size).to eq(1)
      expect(result.first.id).to eq(verbier.id)
    end

    it "finds competitions by city (case-insensitive)" do
      result = repo.search("madonna")

      expect(result.size).to eq(1)
      expect(result.first.id).to eq(madonna.id)
    end

    it "finds competitions by place (case-insensitive)" do
      result = repo.search("pyrenees")

      expect(result.size).to eq(1)
      expect(result.first.id).to eq(andorra.id)
    end

    it "finds multiple matches" do
      result = repo.search("world cup")

      expect(result.size).to eq(3)
      expect(result.map(&:id)).to contain_exactly(verbier.id, madonna.id, andorra.id)
    end

    it "returns empty array for blank query" do
      expect(repo.search("")).to eq([])
      expect(repo.search(nil)).to eq([])
    end

    it "returns empty array for no matches" do
      result = repo.search("nonexistent")

      expect(result).to be_empty
    end
  end

  describe "#create" do
    context "with valid attributes" do
      let(:attrs) do
        {
          name: "World Cup Test 2024",
          city: "Test City",
          place: "Test Place",
          country: "CHE",
          description: "Test description",
          start_date: Date.current + 30.days,
          end_date: Date.current + 32.days,
          webpage_url: "https://example.com"
        }
      end

      it "creates a competition and returns a Structs::Competition" do
        result = repo.create(attrs)

        expect(result).to be_a(Structs::Competition)
        expect(result.name).to eq("World Cup Test 2024")
        expect(result.city).to eq("Test City")
        expect(result.country).to eq("CHE")
      end

      it "persists to database" do
        expect {
          repo.create(attrs)
        }.to change(Competition, :count).by(1)
      end
    end

    # Note: Invalid attributes are caught by the contract validation layer,
    # not the repo layer. The repo assumes valid data from operations.
    # Database constraints (like country varchar(3)) will raise exceptions
    # if violated, which is expected behavior for data integrity.
  end

  describe "#update" do
    let!(:competition) { create(:competition, name: "Original Name") }

    context "with valid attributes" do
      it "updates and returns a Structs::Competition" do
        result = repo.update(competition.id, name: "Updated Name")

        expect(result).to be_a(Structs::Competition)
        expect(result.name).to eq("Updated Name")
      end

      it "persists changes to database" do
        repo.update(competition.id, name: "Updated Name")

        expect(Competition.find(competition.id).name).to eq("Updated Name")
      end
    end

    # Note: Invalid attributes are caught by the contract validation layer.
    # The repo assumes valid data from operations.

    context "when competition not found" do
      it "returns nil" do
        result = repo.update(999999, name: "Test")

        expect(result).to be_nil
      end
    end
  end

  describe "#delete" do
    let!(:competition) { create(:competition) }

    it "deletes the competition and returns true" do
      result = repo.delete(competition.id)

      expect(result).to be true
      expect(Competition.exists?(competition.id)).to be false
    end

    context "when competition not found" do
      it "returns nil" do
        result = repo.delete(999999)

        expect(result).to be_nil
      end
    end

    context "when competition has associated races" do
      let!(:race_type) { create(:race_type, :individual) }
      
      before do
        competition.races.create!(
          race_type: race_type,
          name: "Test Race",
          stage: "qualification",
          start_time: competition.start_date.to_time,
          position: 1,
          status: "scheduled"
        )
      end

      it "deletes the competition and cascades to races" do
        expect {
          repo.delete(competition.id)
        }.to change(Competition, :count).by(-1)
      end
    end
  end

  describe "logo handling" do
    let!(:competition) { create(:competition, :with_logo) }

    it "includes logo_url in struct when logo is attached" do
      result = repo.find(competition.id)

      expect(result.logo_url).to be_present
    end

    it "handles competitions without logos" do
      competition_without_logo = create(:competition)
      result = repo.find(competition_without_logo.id)

      expect(result.logo_url).to be_nil
    end
  end
end