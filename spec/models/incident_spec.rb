# frozen_string_literal: true

require "rails_helper"

RSpec.describe Incident do
  describe "associations" do
    it { is_expected.to belong_to(:race) }
    it { is_expected.to belong_to(:race_location).optional }
    it { is_expected.to belong_to(:decided_by_user).class_name("User").optional }
    it { is_expected.to have_many(:reports).dependent(:nullify) }
    it { is_expected.to have_many(:incident_penalties).dependent(:destroy) }
    it { is_expected.to have_many(:penalties).through(:incident_penalties) }
  end

  describe "model is thin (Hanami-hybrid architecture)" do
    it "has no scopes defined" do
      # Incident model should have no scopes - all query logic belongs in IncidentRepo
      expect(described_class).not_to respond_to(:pending)
      expect(described_class).not_to respond_to(:approved)
      expect(described_class).not_to respond_to(:rejected)
      expect(described_class).not_to respond_to(:for_race)
      expect(described_class).not_to respond_to(:decided)
    end

    it "has no business logic methods" do
      incident = described_class.new

      # These methods should NOT exist on the model - they belong in Structs::Incident
      expect(incident).not_to respond_to(:approve!)
      expect(incident).not_to respond_to(:reject!)
      expect(incident).not_to respond_to(:reopen!)
      expect(incident).not_to respond_to(:can_decide?)
      expect(incident).not_to respond_to(:can_reopen?)
      expect(incident).not_to respond_to(:decided?)
    end

    it "has no enum defined (enums belong in Types)" do
      # Status enum should be defined in Types::IncidentStatus, not in model
      expect(described_class.defined_enums).to be_empty
    end

    it "has no custom validations defined (only implicit belongs_to presence)" do
      # All business validations should be in Operations::Contracts
      # belongs_to associations add implicit presence validations by default in Rails 5+
      incident = described_class.new

      # Model should only have validators from belongs_to associations (implicit presence)
      # No custom validates :field, presence: true etc. should be in the model
      validator_classes = incident._validators.values.flatten.map(&:class).uniq

      # Only ActiveRecord's automatic belongs_to presence validators should exist
      expect(validator_classes).to all(eq(ActiveRecord::Validations::PresenceValidator))
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:race_id).of_type(:integer) }
    it { is_expected.to have_db_column(:race_location_id).of_type(:integer) }
    it { is_expected.to have_db_column(:status).of_type(:string) }
    it { is_expected.to have_db_column(:description).of_type(:text) }
    it { is_expected.to have_db_column(:decided_by_user_id).of_type(:integer) }
    it { is_expected.to have_db_column(:decided_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index(:race_id) }
    it { is_expected.to have_db_index(:race_location_id) }
    it { is_expected.to have_db_index(:status) }
    it { is_expected.to have_db_index(:decided_by_user_id) }
  end

  describe "default values" do
    it "has default status of pending" do
      incident = described_class.new
      expect(incident.status).to eq("pending")
    end
  end

  describe "data integrity" do
    subject(:incident) { create(:incident) }

    it "requires a race" do
      incident.race = nil
      expect(incident).not_to be_valid
    end

    it "allows optional race_location" do
      incident.race_location = nil
      expect(incident).to be_valid
    end

    it "allows optional decided_by_user" do
      incident.decided_by_user = nil
      expect(incident).to be_valid
    end

    it "allows optional description" do
      incident.description = nil
      expect(incident).to be_valid
    end

    it "allows optional decided_at" do
      incident.decided_at = nil
      expect(incident).to be_valid
    end
  end

  describe "report relationship" do
    it "can have multiple reports" do
      incident = create(:incident)
      race = incident.race
      location = incident.race_location || create(:race_location, race: race)

      report1 = create(:report, race: race, race_location: location, incident: incident, status: "confirmed")
      report2 = create(:report, race: race, race_location: location, incident: incident, status: "confirmed")

      expect(incident.reports).to contain_exactly(report1, report2)
    end

    it "nullifies reports when incident is destroyed (does not delete them)" do
      incident = create(:incident)
      race = incident.race
      location = incident.race_location || create(:race_location, race: race)
      report = create(:report, race: race, race_location: location, incident: incident, status: "confirmed")

      expect { incident.destroy }.not_to change(Report, :count)

      report.reload
      expect(report.incident_id).to be_nil
    end
  end

  describe "penalty relationship" do
    it "can have multiple penalties through incident_penalties" do
      incident = create(:incident)
      penalty1 = create(:penalty, :false_start)
      penalty2 = create(:penalty, :wrong_gate)

      create(:incident_penalty, incident: incident, penalty: penalty1)
      create(:incident_penalty, incident: incident, penalty: penalty2)

      expect(incident.penalties).to contain_exactly(penalty1, penalty2)
    end

    it "destroys incident_penalties when incident is destroyed" do
      incident = create(:incident)
      penalty = create(:penalty)
      create(:incident_penalty, incident: incident, penalty: penalty)

      expect { incident.destroy }.to change(IncidentPenalty, :count).by(-1)
    end

    it "does not destroy penalties when incident is destroyed" do
      incident = create(:incident)
      penalty = create(:penalty)
      create(:incident_penalty, incident: incident, penalty: penalty)

      expect { incident.destroy }.not_to change(Penalty, :count)
    end
  end

  describe "factory" do
    it "creates a valid incident with default attributes" do
      incident = build(:incident)
      expect(incident).to be_valid
    end

    it "creates a valid pending incident" do
      incident = create(:incident, :pending)
      expect(incident.status).to eq("pending")
      expect(incident.decided_at).to be_nil
      expect(incident.decided_by_user).to be_nil
    end

    it "creates a valid approved incident" do
      incident = create(:incident, :approved)
      expect(incident.status).to eq("approved")
      expect(incident.decided_at).to be_present
      expect(incident.decided_by_user).to be_present
    end

    it "creates a valid rejected incident" do
      incident = create(:incident, :rejected)
      expect(incident.status).to eq("rejected")
      expect(incident.decided_at).to be_present
      expect(incident.decided_by_user).to be_present
    end

    it "creates incident with reports using trait" do
      incident = create(:incident, :with_reports, reports_count: 3)
      expect(incident.reports.count).to eq(3)
    end

    it "creates incident with penalties using trait" do
      incident = create(:incident, :with_penalties, penalties_count: 2)
      expect(incident.penalties.count).to eq(2)
    end
  end
end
