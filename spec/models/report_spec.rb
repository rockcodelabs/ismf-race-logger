# frozen_string_literal: true

require "rails_helper"

RSpec.describe Report do
  describe "associations" do
    it { is_expected.to belong_to(:race) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:race_location) }
    it { is_expected.to belong_to(:race_participation).optional }
    it { is_expected.to belong_to(:incident).optional }
  end

  describe "model is thin (Hanami-hybrid architecture)" do
    it "has no scopes defined" do
      # Report model should have no scopes - all query logic belongs in ReportRepo
      expect(described_class).not_to respond_to(:pending)
      expect(described_class).not_to respond_to(:confirmed)
      expect(described_class).not_to respond_to(:rejected)
      expect(described_class).not_to respond_to(:for_race)
      expect(described_class).not_to respond_to(:by_bib)
    end

    it "has no business logic methods" do
      report = described_class.new

      # These methods should NOT exist on the model - they belong in Structs::Report
      expect(report).not_to respond_to(:can_confirm?)
      expect(report).not_to respond_to(:can_reject?)
      expect(report).not_to respond_to(:can_reopen?)
      expect(report).not_to respond_to(:confirm!)
      expect(report).not_to respond_to(:reject!)
      expect(report).not_to respond_to(:linked_to_incident?)
    end

    it "has no enum defined (enums belong in Types)" do
      # Status enum should be defined in Types::ReportStatus, not in model
      expect(described_class.defined_enums).to be_empty
    end

    it "has no custom validations defined (only implicit belongs_to presence)" do
      # All business validations should be in Operations::Contracts::CreateReport
      # belongs_to associations add implicit presence validations by default in Rails 5+
      report = described_class.new

      # Model should only have validators from belongs_to associations (implicit presence)
      # No custom validates :field, presence: true etc. should be in the model
      validator_classes = report._validators.values.flatten.map(&:class).uniq

      # Only ActiveRecord's automatic belongs_to presence validators should exist
      expect(validator_classes).to all(eq(ActiveRecord::Validations::PresenceValidator))
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:client_uuid).of_type(:uuid) }
    it { is_expected.to have_db_column(:race_id).of_type(:integer) }
    it { is_expected.to have_db_column(:incident_id).of_type(:integer) }
    it { is_expected.to have_db_column(:user_id).of_type(:integer) }
    it { is_expected.to have_db_column(:race_location_id).of_type(:integer) }
    it { is_expected.to have_db_column(:race_participation_id).of_type(:integer) }
    it { is_expected.to have_db_column(:bib_number).of_type(:integer) }
    it { is_expected.to have_db_column(:athlete_position).of_type(:integer) }
    it { is_expected.to have_db_column(:description).of_type(:text) }
    it { is_expected.to have_db_column(:status).of_type(:string) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index(:client_uuid).unique(true) }
    it { is_expected.to have_db_index(:race_id) }
    it { is_expected.to have_db_index(:incident_id) }
    it { is_expected.to have_db_index(:user_id) }
    it { is_expected.to have_db_index(:race_location_id) }
    it { is_expected.to have_db_index(:race_participation_id) }
    it { is_expected.to have_db_index(:status) }
    it { is_expected.to have_db_index(:bib_number) }
  end

  describe "default values" do
    it "has default status of pending_review" do
      report = described_class.new
      expect(report.status).to eq("pending_review")
    end
  end

  describe "client_uuid generation" do
    it "auto-generates client_uuid before validation if not present" do
      race = create(:race)
      user = create(:user)
      race_location = create(:race_location, race: race)
      participation = create(:race_participation, race: race)

      report = described_class.new(
        race: race,
        user: user,
        race_location: race_location,
        race_participation: participation,
        bib_number: participation.bib_number
      )

      report.valid?
      expect(report.client_uuid).to be_present
      expect(report.client_uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    end

    it "preserves existing client_uuid if already set" do
      existing_uuid = "550e8400-e29b-41d4-a716-446655440000"
      report = described_class.new(client_uuid: existing_uuid)

      report.valid?
      expect(report.client_uuid).to eq(existing_uuid)
    end
  end

  describe "data integrity" do
    subject(:report) { create(:report) }

    it "requires a race" do
      report.race = nil
      expect(report).not_to be_valid
    end

    it "requires a user" do
      report.user = nil
      expect(report).not_to be_valid
    end

    it "requires a race_location" do
      report.race_location = nil
      expect(report).not_to be_valid
    end

    it "allows optional race_participation (can be nil)" do
      report.race_participation = nil
      expect(report).to be_valid
    end

    it "allows optional incident (can be nil)" do
      report.incident = nil
      expect(report).to be_valid
    end

    it "allows optional description" do
      report.description = nil
      expect(report).to be_valid
    end

    it "allows optional athlete_position" do
      report.athlete_position = nil
      expect(report).to be_valid
    end
  end

  describe "factory" do
    it "creates a valid report with default attributes" do
      report = build(:report)
      expect(report).to be_valid
    end

    it "creates a valid pending_review report" do
      report = create(:report, :pending_review)
      expect(report.status).to eq("pending_review")
    end

    it "creates a valid confirmed report" do
      report = create(:report, :confirmed)
      expect(report.status).to eq("confirmed")
    end

    it "creates a valid rejected report" do
      report = create(:report, :rejected)
      expect(report.status).to eq("rejected")
    end

    it "creates a report linked to an incident" do
      report = create(:report, :linked_to_incident)
      expect(report.incident).to be_present
      expect(report.status).to eq("confirmed")
    end
  end
end
