# frozen_string_literal: true

require "rails_helper"

RSpec.describe Structs::IncidentSummary do
  subject(:summary) do
    described_class.new(
      id: 1,
      race_id: 10,
      race_location_id: race_location_id,
      race_location_name: race_location_name,
      status: status,
      reports_count: reports_count,
      penalties_count: penalties_count,
      bib_numbers: bib_numbers,
      created_at: created_at
    )
  end

  let(:status) { "pending" }
  let(:race_location_id) { 3 }
  let(:race_location_name) { "Uphill Checkpoint" }
  let(:reports_count) { 2 }
  let(:penalties_count) { 0 }
  let(:bib_numbers) { [ 42, 15 ] }
  let(:created_at) { Time.current }

  describe "attributes" do
    it "has all expected attributes" do
      expect(summary.id).to eq(1)
      expect(summary.race_id).to eq(10)
      expect(summary.race_location_id).to eq(3)
      expect(summary.race_location_name).to eq("Uphill Checkpoint")
      expect(summary.status).to eq("pending")
      expect(summary.reports_count).to eq(2)
      expect(summary.penalties_count).to eq(0)
      expect(summary.bib_numbers).to eq([ 42, 15 ])
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
    describe "#pending?" do
      context "when status is pending" do
        let(:status) { "pending" }

        it "returns true" do
          expect(summary.pending?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "approved" }

        it "returns false" do
          expect(summary.pending?).to be false
        end
      end
    end

    describe "#approved?" do
      context "when status is approved" do
        let(:status) { "approved" }

        it "returns true" do
          expect(summary.approved?).to be true
        end
      end

      context "when status is different" do
        let(:status) { "pending" }

        it "returns false" do
          expect(summary.approved?).to be false
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
        let(:status) { "pending" }

        it "returns false" do
          expect(summary.rejected?).to be false
        end
      end
    end
  end

  describe "display helpers" do
    describe "#status_badge_class" do
      context "when pending" do
        let(:status) { "pending" }

        it "returns yellow styling" do
          expect(summary.status_badge_class).to eq("bg-yellow-100 text-yellow-800")
        end
      end

      context "when approved" do
        let(:status) { "approved" }

        it "returns green styling" do
          expect(summary.status_badge_class).to eq("bg-green-100 text-green-800")
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
      context "when pending" do
        let(:status) { "pending" }

        it "returns Pending" do
          expect(summary.status_label).to eq("Pending")
        end
      end

      context "when approved" do
        let(:status) { "approved" }

        it "returns Approved" do
          expect(summary.status_label).to eq("Approved")
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
      context "when bib_numbers is present" do
        let(:bib_numbers) { [ 42, 15, 7 ] }

        it "returns comma-separated list" do
          expect(summary.bib_display).to eq("42, 15, 7")
        end
      end

      context "when bib_numbers has one element" do
        let(:bib_numbers) { [ 42 ] }

        it "returns single number" do
          expect(summary.bib_display).to eq("42")
        end
      end

      context "when bib_numbers is empty" do
        let(:bib_numbers) { [] }

        it "returns dash" do
          expect(summary.bib_display).to eq("—")
        end
      end

      context "when bib_numbers is nil" do
        let(:bib_numbers) { nil }

        it "returns dash" do
          expect(summary.bib_display).to eq("—")
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

    describe "#has_penalties?" do
      context "when penalties_count is greater than 0" do
        let(:penalties_count) { 2 }

        it "returns true" do
          expect(summary.has_penalties?).to be true
        end
      end

      context "when penalties_count is 0" do
        let(:penalties_count) { 0 }

        it "returns false" do
          expect(summary.has_penalties?).to be false
        end
      end

      context "when penalties_count is nil" do
        let(:penalties_count) { nil }

        it "returns false" do
          expect(summary.has_penalties?).to be false
        end
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
          race_location_id: 1,
          race_location_name: "Location #{i}",
          status: "pending",
          reports_count: 1,
          penalties_count: 0,
          bib_numbers: [ i ],
          created_at: Time.current
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
        race_location_id: 2,
        race_location_name: "Test Location",
        status: "approved",
        reports_count: 3,
        penalties_count: 1,
        bib_numbers: [ 10, 20 ],
        created_at: Time.current
      )

      expect(summary.id).to eq(42)
      expect(summary.approved?).to be true
      expect(summary.has_penalties?).to be true
      expect(summary.bib_display).to eq("10, 20")
    end
  end
end
