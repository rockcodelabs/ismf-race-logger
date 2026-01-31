# frozen_string_literal: true

require "rails_helper"

RSpec.describe Structs::Report do
  subject(:report) do
    described_class.new(
      id: 1,
      client_uuid: "550e8400-e29b-41d4-a716-446655440000",
      race_id: 10,
      incident_id: incident_id,
      user_id: 5,
      race_location_id: 3,
      race_participation_id: 20,
      bib_number: 42,
      athlete_position: athlete_position,
      description: "Athlete cut the course",
      status: status,
      created_at: Time.current,
      updated_at: Time.current,
      race_location_name: race_location_name,
      athlete_name: athlete_name,
      user_name: "Referee Smith"
    )
  end

  let(:status) { "pending_review" }
  let(:incident_id) { nil }
  let(:athlete_position) { nil }
  let(:race_location_name) { "Uphill Checkpoint" }
  let(:athlete_name) { "John Doe" }

  describe "attributes" do
    it "has all expected attributes" do
      expect(report.id).to eq(1)
      expect(report.client_uuid).to eq("550e8400-e29b-41d4-a716-446655440000")
      expect(report.race_id).to eq(10)
      expect(report.incident_id).to be_nil
      expect(report.user_id).to eq(5)
      expect(report.race_location_id).to eq(3)
      expect(report.race_participation_id).to eq(20)
      expect(report.bib_number).to eq(42)
      expect(report.athlete_position).to be_nil
      expect(report.description).to eq("Athlete cut the course")
      expect(report.status).to eq("pending_review")
      expect(report.created_at).to be_a(Time)
      expect(report.updated_at).to be_a(Time)
      expect(report.race_location_name).to eq("Uphill Checkpoint")
      expect(report.athlete_name).to eq("John Doe")
      expect(report.user_name).to eq("Referee Smith")
    end

    it "is immutable" do
      expect { report.instance_variable_set(:@id, 999) }.not_to change { report.id }
    end
  end

  describe "status helpers" do
    describe "#pending_review?" do
      context "when status is pending_review" do
        let(:status) { "pending_review" }

        it "returns true" do
          expect(report.pending_review?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "confirmed" }

        it "returns false" do
          expect(report.pending_review?).to be false
        end
      end
    end

    describe "#confirmed?" do
      context "when status is confirmed" do
        let(:status) { "confirmed" }

        it "returns true" do
          expect(report.confirmed?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "pending_review" }

        it "returns false" do
          expect(report.confirmed?).to be false
        end
      end
    end

    describe "#rejected?" do
      context "when status is rejected" do
        let(:status) { "rejected" }

        it "returns true" do
          expect(report.rejected?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "pending_review" }

        it "returns false" do
          expect(report.rejected?).to be false
        end
      end
    end
  end

  describe "action helpers" do
    describe "#can_confirm?" do
      context "when pending_review" do
        let(:status) { "pending_review" }

        it "returns true" do
          expect(report.can_confirm?).to be true
        end
      end

      context "when already confirmed" do
        let(:status) { "confirmed" }

        it "returns false" do
          expect(report.can_confirm?).to be false
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns false" do
          expect(report.can_confirm?).to be false
        end
      end
    end

    describe "#can_reject?" do
      context "when pending_review" do
        let(:status) { "pending_review" }

        it "returns true" do
          expect(report.can_reject?).to be true
        end
      end

      context "when already confirmed" do
        let(:status) { "confirmed" }

        it "returns false" do
          expect(report.can_reject?).to be false
        end
      end
    end

    describe "#can_reopen?" do
      context "when pending_review" do
        let(:status) { "pending_review" }

        it "returns false" do
          expect(report.can_reopen?).to be false
        end
      end

      context "when confirmed" do
        let(:status) { "confirmed" }

        it "returns true" do
          expect(report.can_reopen?).to be true
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns true" do
          expect(report.can_reopen?).to be true
        end
      end
    end
  end

  describe "incident helpers" do
    describe "#has_incident?" do
      context "when incident_id is nil" do
        let(:incident_id) { nil }

        it "returns false" do
          expect(report.has_incident?).to be false
        end
      end

      context "when incident_id is present" do
        let(:incident_id) { 5 }

        it "returns true" do
          expect(report.has_incident?).to be true
        end
      end
    end

    describe "#can_merge?" do
      context "when confirmed and no incident" do
        let(:status) { "confirmed" }
        let(:incident_id) { nil }

        it "returns true" do
          expect(report.can_merge?).to be true
        end
      end

      context "when confirmed but already has incident" do
        let(:status) { "confirmed" }
        let(:incident_id) { 5 }

        it "returns false" do
          expect(report.can_merge?).to be false
        end
      end

      context "when pending_review" do
        let(:status) { "pending_review" }
        let(:incident_id) { nil }

        it "returns false" do
          expect(report.can_merge?).to be false
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }
        let(:incident_id) { nil }

        it "returns false" do
          expect(report.can_merge?).to be false
        end
      end
    end
  end

  describe "display helpers" do
    describe "#status_css_class" do
      context "when pending_review" do
        let(:status) { "pending_review" }

        it "returns yellow styling" do
          expect(report.status_css_class).to eq("bg-yellow-100 text-yellow-800")
        end
      end

      context "when confirmed" do
        let(:status) { "confirmed" }

        it "returns blue styling" do
          expect(report.status_css_class).to eq("bg-blue-100 text-blue-800")
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns red styling" do
          expect(report.status_css_class).to eq("bg-red-100 text-red-800")
        end
      end
    end

    describe "#status_display" do
      context "when pending_review" do
        let(:status) { "pending_review" }

        it "returns human-readable format" do
          expect(report.status_display).to eq("Pending Review")
        end
      end

      context "when confirmed" do
        let(:status) { "confirmed" }

        it "returns Confirmed" do
          expect(report.status_display).to eq("Confirmed")
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns Rejected" do
          expect(report.status_display).to eq("Rejected")
        end
      end
    end

    describe "#bib_display" do
      context "when no athlete_position" do
        let(:athlete_position) { nil }

        it "returns just the bib number" do
          expect(report.bib_display).to eq("42")
        end
      end

      context "when athlete_position is 0" do
        let(:athlete_position) { 0 }

        it "returns just the bib number" do
          expect(report.bib_display).to eq("42")
        end
      end

      context "when athlete_position is present" do
        let(:athlete_position) { 1 }

        it "returns bib with position indicator" do
          expect(report.bib_display).to eq("42 (Athlete 1)")
        end
      end

      context "when athlete_position is 2" do
        let(:athlete_position) { 2 }

        it "returns bib with position indicator" do
          expect(report.bib_display).to eq("42 (Athlete 2)")
        end
      end
    end

    describe "#location_display" do
      context "when race_location_name is present" do
        let(:race_location_name) { "Summit Checkpoint" }

        it "returns the location name" do
          expect(report.location_display).to eq("Summit Checkpoint")
        end
      end

      context "when race_location_name is nil" do
        let(:race_location_name) { nil }

        it "returns Unknown" do
          expect(report.location_display).to eq("Unknown")
        end
      end

      context "when race_location_name is empty" do
        let(:race_location_name) { "" }

        it "returns Unknown" do
          expect(report.location_display).to eq("Unknown")
        end
      end
    end

    describe "#athlete_display" do
      context "when athlete_name is present" do
        let(:athlete_name) { "Jane Smith" }

        it "returns the athlete name" do
          expect(report.athlete_display).to eq("Jane Smith")
        end
      end

      context "when athlete_name is nil" do
        let(:athlete_name) { nil }

        it "returns bib number fallback" do
          expect(report.athlete_display).to eq("Bib #42")
        end
      end

      context "when athlete_name is empty" do
        let(:athlete_name) { "" }

        it "returns bib number fallback" do
          expect(report.athlete_display).to eq("Bib #42")
        end
      end
    end

    describe "#time_ago" do
      it "returns created_at for Rails helper usage" do
        expect(report.time_ago).to eq(report.created_at)
      end
    end
  end

  describe "type coercion" do
    it "transforms string keys to symbols" do
      report = described_class.new(
        "id" => 1,
        "client_uuid" => "550e8400-e29b-41d4-a716-446655440000",
        "race_id" => 10,
        "incident_id" => nil,
        "user_id" => 5,
        "race_location_id" => 3,
        "race_participation_id" => 20,
        "bib_number" => 42,
        "athlete_position" => nil,
        "description" => "Test",
        "status" => "pending_review",
        "created_at" => Time.current,
        "updated_at" => Time.current,
        "race_location_name" => nil,
        "athlete_name" => nil,
        "user_name" => nil
      )

      expect(report.id).to eq(1)
      expect(report.race_id).to eq(10)
    end
  end

  describe "optional attributes" do
    it "allows nil for optional fields" do
      report = described_class.new(
        id: 1,
        client_uuid: "550e8400-e29b-41d4-a716-446655440000",
        race_id: 10,
        incident_id: nil,
        user_id: 5,
        race_location_id: 3,
        race_participation_id: 20,
        bib_number: 42,
        athlete_position: nil,
        description: nil,
        status: "pending_review",
        created_at: Time.current,
        updated_at: Time.current,
        race_location_name: nil,
        athlete_name: nil,
        user_name: nil
      )

      expect(report.incident_id).to be_nil
      expect(report.athlete_position).to be_nil
      expect(report.description).to be_nil
      expect(report.race_location_name).to be_nil
      expect(report.athlete_name).to be_nil
      expect(report.user_name).to be_nil
    end
  end
end
