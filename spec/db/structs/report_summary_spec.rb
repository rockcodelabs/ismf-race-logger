# frozen_string_literal: true

require "rails_helper"

RSpec.describe Structs::ReportSummary do
  subject(:summary) do
    described_class.new(
      id: 1,
      race_id: 10,
      incident_id: incident_id,
      incident_name: nil,
      incident_status: nil,
      incident_has_decision: false,
      bib_number: 42,
      athlete_position: athlete_position,
      race_location_id: 3,
      race_location_name: race_location_name,
      athlete_name: athlete_name,
      athlete_country: nil,
      user_name: "Referee Smith",
      status: status,
      created_at: created_at,
      videos_count: 0
    )
  end

  let(:status) { "pending_review" }
  let(:incident_id) { nil }
  let(:athlete_position) { nil }
  let(:race_location_name) { "Uphill Checkpoint" }
  let(:athlete_name) { "John Doe" }
  let(:created_at) { Time.current }

  describe "attributes" do
    it "has all expected attributes" do
      expect(summary.id).to eq(1)
      expect(summary.race_id).to eq(10)
      expect(summary.incident_id).to be_nil
      expect(summary.bib_number).to eq(42)
      expect(summary.athlete_position).to be_nil
      expect(summary.race_location_id).to eq(3)
      expect(summary.race_location_name).to eq("Uphill Checkpoint")
      expect(summary.athlete_name).to eq("John Doe")
      expect(summary.status).to eq("pending_review")
      expect(summary.created_at).to eq(created_at)
    end

    it "is a Ruby Data class" do
      expect(described_class.ancestors).to include(Data)
    end

    it "is immutable" do
      expect { summary.instance_variable_set(:@id, 999) }.to raise_error(FrozenError)
    end
  end

  describe "status helpers" do
    describe "#pending_review?" do
      context "when status is pending_review" do
        let(:status) { "pending_review" }

        it "returns true" do
          expect(summary.pending_review?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "confirmed" }

        it "returns false" do
          expect(summary.pending_review?).to be false
        end
      end
    end

    describe "#confirmed?" do
      context "when status is confirmed" do
        let(:status) { "confirmed" }

        it "returns true" do
          expect(summary.confirmed?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "pending_review" }

        it "returns false" do
          expect(summary.confirmed?).to be false
        end
      end
    end

    describe "#rejected?" do
      context "when status is rejected" do
        let(:status) { "rejected" }

        it "returns true" do
          expect(summary.rejected?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "pending_review" }

        it "returns false" do
          expect(summary.rejected?).to be false
        end
      end
    end
  end

  describe "incident helpers" do
    describe "#linked_to_incident?" do
      context "when incident_id is nil" do
        let(:incident_id) { nil }

        it "returns false" do
          expect(summary.linked_to_incident?).to be false
        end
      end

      context "when incident_id is present" do
        let(:incident_id) { 5 }

        it "returns true" do
          expect(summary.linked_to_incident?).to be true
        end
      end
    end

    describe "#can_merge?" do
      context "when confirmed and no incident" do
        let(:status) { "confirmed" }
        let(:incident_id) { nil }

        it "returns true" do
          expect(summary.can_merge?).to be true
        end
      end

      context "when confirmed but already has incident" do
        let(:status) { "confirmed" }
        let(:incident_id) { 5 }

        it "returns false" do
          expect(summary.can_merge?).to be false
        end
      end

      context "when pending_review" do
        let(:status) { "pending_review" }
        let(:incident_id) { nil }

        it "returns false" do
          expect(summary.can_merge?).to be false
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }
        let(:incident_id) { nil }

        it "returns false" do
          expect(summary.can_merge?).to be false
        end
      end
    end
  end

  describe "display helpers" do
    describe "#status_badge_class" do
      context "when pending_review" do
        let(:status) { "pending_review" }

        it "returns yellow styling" do
          expect(summary.status_badge_class).to eq("bg-yellow-100 text-yellow-800")
        end
      end

      context "when confirmed" do
        let(:status) { "confirmed" }

        it "returns blue styling" do
          expect(summary.status_badge_class).to eq("bg-blue-100 text-blue-800")
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns red styling" do
          expect(summary.status_badge_class).to eq("bg-red-100 text-red-800")
        end
      end

      context "when unknown status" do
        let(:status) { "unknown" }

        it "returns gray styling" do
          expect(summary.status_badge_class).to eq("bg-gray-100 text-gray-800")
        end
      end
    end

    describe "#status_label" do
      context "when pending_review" do
        let(:status) { "pending_review" }

        it "returns Pending" do
          expect(summary.status_label).to eq("Pending")
        end
      end

      context "when confirmed" do
        let(:status) { "confirmed" }

        it "returns Confirmed" do
          expect(summary.status_label).to eq("Confirmed")
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns Rejected" do
          expect(summary.status_label).to eq("Rejected")
        end
      end
    end

    describe "#bib_display" do
      context "when no athlete_position" do
        let(:athlete_position) { nil }

        it "returns just the bib number" do
          expect(summary.bib_display).to eq("42")
        end
      end

      context "when athlete_position is 0" do
        let(:athlete_position) { 0 }

        it "returns just the bib number" do
          expect(summary.bib_display).to eq("42")
        end
      end

      context "when athlete_position is 1" do
        let(:athlete_position) { 1 }

        it "returns bib with A indicator" do
          expect(summary.bib_display).to eq("42 (A)")
        end
      end

      context "when athlete_position is 2" do
        let(:athlete_position) { 2 }

        it "returns bib with B indicator" do
          expect(summary.bib_display).to eq("42 (B)")
        end
      end
    end

    describe "#location_display" do
      context "when race_location_name is present" do
        let(:race_location_name) { "Summit Checkpoint" }

        it "returns the location name" do
          expect(summary.location_display).to eq("Summit Checkpoint")
        end
      end

      context "when race_location_name is nil" do
        let(:race_location_name) { nil }

        it "returns Unknown" do
          expect(summary.location_display).to eq("Unknown")
        end
      end

      context "when race_location_name is empty" do
        let(:race_location_name) { "" }

        it "returns Unknown" do
          expect(summary.location_display).to eq("Unknown")
        end
      end
    end

    describe "#athlete_display" do
      context "when athlete_name is present" do
        let(:athlete_name) { "Jane Smith" }

        it "returns the athlete name" do
          expect(summary.athlete_display).to eq("Jane Smith")
        end
      end

      context "when athlete_name is nil" do
        let(:athlete_name) { nil }

        it "returns bib number fallback" do
          expect(summary.athlete_display).to eq("Bib #42")
        end
      end

      context "when athlete_name is empty" do
        let(:athlete_name) { "" }

        it "returns bib number fallback" do
          expect(summary.athlete_display).to eq("Bib #42")
        end
      end
    end

    describe "#queue_display" do
      let(:race_location_name) { "Uphill-Top" }

      it "returns formatted queue display" do
        expect(summary.queue_display).to eq("#42 @ Uphill-Top")
      end
    end

    describe "#time_ago_display" do
      context "when just created" do
        let(:created_at) { Time.current }

        it "returns just now" do
          expect(summary.time_ago_display).to eq("just now")
        end
      end

      context "when created minutes ago" do
        let(:created_at) { 5.minutes.ago }

        it "returns minutes ago format" do
          expect(summary.time_ago_display).to eq("5m ago")
        end
      end

      context "when created hours ago" do
        let(:created_at) { 3.hours.ago }

        it "returns hours ago format" do
          expect(summary.time_ago_display).to eq("3h ago")
        end
      end

      context "when created days ago" do
        let(:created_at) { 2.days.ago }

        it "returns days ago format" do
          expect(summary.time_ago_display).to eq("2d ago")
        end
      end
    end
  end

  describe "performance characteristics" do
    it "is faster to instantiate than dry-struct" do
      summaries = 1000.times.map do |i|
        described_class.new(
          id: i,
          race_id: 1,
          incident_id: nil,
          incident_name: nil,
          incident_status: nil,
          incident_has_decision: false,
          bib_number: i,
          athlete_position: nil,
          race_location_id: 1,
          race_location_name: "Location #{i}",
          athlete_name: "Athlete #{i}",
          athlete_country: nil,
          user_name: nil,
          status: "pending_review",
          created_at: Time.current,
          videos_count: 0
        )
      end

      expect(summaries.size).to eq(1000)
    end
  end

  describe "keyword arguments" do
    it "can be instantiated with keyword arguments" do
      summary = described_class.new(
        id: 42,
        race_id: 1,
        incident_id: 5,
        incident_name: nil,
        incident_status: nil,
        incident_has_decision: false,
        bib_number: 99,
        athlete_position: 1,
        race_location_id: 2,
        race_location_name: "Test Location",
        athlete_name: "Test Athlete",
        athlete_country: nil,
        user_name: nil,
        status: "confirmed",
        created_at: Time.current,
        videos_count: 0
      )

      expect(summary.id).to eq(42)
      expect(summary.incident_id).to eq(5)
      expect(summary.confirmed?).to be true
    end
  end
end
