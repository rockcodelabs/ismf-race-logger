# frozen_string_literal: true

require "rails_helper"

RSpec.describe Structs::Incident do
  subject(:incident) do
    described_class.new(
      id: 1,
      client_uuid: "550e8400-e29b-41d4-a716-446655440000",
      race_id: 10,
      race_location_id: race_location_id,
      status: status,
      description: "Course cutting violation",
      decided_by_user_id: decided_by_user_id,
      decided_at: decided_at,
      created_at: Time.current,
      updated_at: Time.current,
      race_location_name: race_location_name,
      decided_by_user_name: decided_by_user_name,
      reports_count: reports_count,
      penalties_count: penalties_count
    )
  end

  let(:status) { "pending" }
  let(:race_location_id) { 3 }
  let(:race_location_name) { "Uphill Checkpoint" }
  let(:decided_by_user_id) { nil }
  let(:decided_by_user_name) { nil }
  let(:decided_at) { nil }
  let(:reports_count) { 2 }
  let(:penalties_count) { 0 }

  describe "attributes" do
    it "has all expected attributes" do
      expect(incident.id).to eq(1)
      expect(incident.client_uuid).to eq("550e8400-e29b-41d4-a716-446655440000")
      expect(incident.race_id).to eq(10)
      expect(incident.race_location_id).to eq(3)
      expect(incident.status).to eq("pending")
      expect(incident.description).to eq("Course cutting violation")
      expect(incident.decided_by_user_id).to be_nil
      expect(incident.decided_at).to be_nil
      expect(incident.created_at).to be_a(Time)
      expect(incident.updated_at).to be_a(Time)
      expect(incident.race_location_name).to eq("Uphill Checkpoint")
      expect(incident.decided_by_user_name).to be_nil
      expect(incident.reports_count).to eq(2)
      expect(incident.penalties_count).to eq(0)
    end

    it "is immutable" do
      expect { incident.instance_variable_set(:@id, 999) }.not_to change { incident.id }
    end
  end

  describe "status helpers" do
    describe "#pending?" do
      context "when status is pending" do
        let(:status) { "pending" }

        it "returns true" do
          expect(incident.pending?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "approved" }

        it "returns false" do
          expect(incident.pending?).to be false
        end
      end
    end

    describe "#approved?" do
      context "when status is approved" do
        let(:status) { "approved" }

        it "returns true" do
          expect(incident.approved?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "pending" }

        it "returns false" do
          expect(incident.approved?).to be false
        end
      end
    end

    describe "#rejected?" do
      context "when status is rejected" do
        let(:status) { "rejected" }

        it "returns true" do
          expect(incident.rejected?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "pending" }

        it "returns false" do
          expect(incident.rejected?).to be false
        end
      end
    end
  end

  describe "action helpers" do
    describe "#can_decide?" do
      context "when pending" do
        let(:status) { "pending" }

        it "returns true" do
          expect(incident.can_decide?).to be true
        end
      end

      context "when approved" do
        let(:status) { "approved" }

        it "returns false" do
          expect(incident.can_decide?).to be false
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns false" do
          expect(incident.can_decide?).to be false
        end
      end
    end

    describe "#can_reopen?" do
      context "when pending" do
        let(:status) { "pending" }

        it "returns false" do
          expect(incident.can_reopen?).to be false
        end
      end

      context "when approved" do
        let(:status) { "approved" }

        it "returns true" do
          expect(incident.can_reopen?).to be true
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns true" do
          expect(incident.can_reopen?).to be true
        end
      end
    end

    describe "#decided?" do
      context "when decided_at and decided_by_user_id are present" do
        let(:decided_at) { Time.current }
        let(:decided_by_user_id) { 5 }

        it "returns true" do
          expect(incident.decided?).to be true
        end
      end

      context "when decided_at is nil" do
        let(:decided_at) { nil }
        let(:decided_by_user_id) { 5 }

        it "returns false" do
          expect(incident.decided?).to be false
        end
      end

      context "when decided_by_user_id is nil" do
        let(:decided_at) { Time.current }
        let(:decided_by_user_id) { nil }

        it "returns false" do
          expect(incident.decided?).to be false
        end
      end

      context "when both are nil" do
        let(:decided_at) { nil }
        let(:decided_by_user_id) { nil }

        it "returns false" do
          expect(incident.decided?).to be false
        end
      end
    end
  end

  describe "display helpers" do
    describe "#status_css_class" do
      context "when pending" do
        let(:status) { "pending" }

        it "returns yellow styling" do
          expect(incident.status_css_class).to eq("bg-yellow-100 text-yellow-800")
        end
      end

      context "when approved" do
        let(:status) { "approved" }

        it "returns green styling" do
          expect(incident.status_css_class).to eq("bg-green-100 text-green-800")
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns red styling" do
          expect(incident.status_css_class).to eq("bg-red-100 text-red-800")
        end
      end

      # Note: Unknown status cannot be tested because dry-struct constrains
      # valid values to: pending, approved, rejected
    end

    describe "#status_display" do
      context "when pending" do
        let(:status) { "pending" }

        it "returns Pending" do
          expect(incident.status_display).to eq("Pending")
        end
      end

      context "when approved" do
        let(:status) { "approved" }

        it "returns Approved" do
          expect(incident.status_display).to eq("Approved")
        end
      end

      context "when rejected" do
        let(:status) { "rejected" }

        it "returns Rejected" do
          expect(incident.status_display).to eq("Rejected")
        end
      end
    end

    describe "#time_ago" do
      it "returns created_at for Rails helper usage" do
        expect(incident.time_ago).to eq(incident.created_at)
      end
    end
  end

  describe "type coercion" do
    it "transforms string keys to symbols" do
      incident = described_class.new(
        "id" => 1,
        "client_uuid" => "550e8400-e29b-41d4-a716-446655440000",
        "race_id" => 10,
        "race_location_id" => nil,
        "status" => "pending",
        "description" => "Test",
        "decided_by_user_id" => nil,
        "decided_at" => nil,
        "created_at" => Time.current,
        "updated_at" => Time.current,
        "race_location_name" => nil,
        "decided_by_user_name" => nil,
        "reports_count" => nil,
        "penalties_count" => nil
      )

      expect(incident.id).to eq(1)
      expect(incident.race_id).to eq(10)
    end
  end

  describe "optional attributes" do
    it "allows nil for optional fields" do
      incident = described_class.new(
        id: 1,
        client_uuid: "550e8400-e29b-41d4-a716-446655440000",
        race_id: 10,
        race_location_id: nil,
        status: "pending",
        description: nil,
        decided_by_user_id: nil,
        decided_at: nil,
        created_at: Time.current,
        updated_at: Time.current,
        race_location_name: nil,
        decided_by_user_name: nil,
        reports_count: nil,
        penalties_count: nil
      )

      expect(incident.race_location_id).to be_nil
      expect(incident.description).to be_nil
      expect(incident.decided_by_user_id).to be_nil
      expect(incident.decided_at).to be_nil
      expect(incident.race_location_name).to be_nil
      expect(incident.decided_by_user_name).to be_nil
      expect(incident.reports_count).to be_nil
      expect(incident.penalties_count).to be_nil
    end
  end

  describe "with decision data" do
    let(:status) { "approved" }
    let(:decided_by_user_id) { 5 }
    let(:decided_by_user_name) { "Admin User" }
    let(:decided_at) { Time.current }
    let(:penalties_count) { 2 }

    it "has all decision-related data" do
      expect(incident.decided?).to be true
      expect(incident.approved?).to be true
      expect(incident.decided_by_user_id).to eq(5)
      expect(incident.decided_by_user_name).to eq("Admin User")
      expect(incident.decided_at).to be_a(Time)
      expect(incident.penalties_count).to eq(2)
    end
  end
end
