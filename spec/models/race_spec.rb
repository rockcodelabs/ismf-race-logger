# frozen_string_literal: true

require "rails_helper"

RSpec.describe Race do
  describe "associations" do
    it { is_expected.to belong_to(:competition) }
    it { is_expected.to belong_to(:race_type) }
  end

  describe "model is thin (Hanami-hybrid architecture)" do
    it "has no scopes defined" do
      # Race model should have no scopes - all query logic belongs in RaceRepo
      expect(described_class).not_to respond_to(:ordered)
      expect(described_class).not_to respond_to(:scheduled)
      expect(described_class).not_to respond_to(:in_progress)
      expect(described_class).not_to respond_to(:completed)
      expect(described_class).not_to respond_to(:for_competition)
    end

    it "has no business logic methods" do
      race = described_class.new

      # These methods should NOT exist on the model - they belong in Structs::Race
      expect(race).not_to respond_to(:display_name)
      expect(race).not_to respond_to(:scheduled?)
      expect(race).not_to respond_to(:in_progress?)
      expect(race).not_to respond_to(:completed?)
      expect(race).not_to respond_to(:can_start?)
      expect(race).not_to respond_to(:can_edit?)
    end

    it "has no custom class methods beyond Rails defaults" do
      # The model should only have Rails-provided methods
      # All custom queries belong in RaceRepo
      custom_methods = described_class.methods - ApplicationRecord.methods
      business_logic_methods = custom_methods.grep(/^(find_by_|search|filter|status)/)
      
      expect(business_logic_methods).to be_empty
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:competition_id).of_type(:integer) }
    it { is_expected.to have_db_column(:race_type_id).of_type(:integer) }
    it { is_expected.to have_db_column(:name).of_type(:string) }
    it { is_expected.to have_db_column(:stage_type).of_type(:string) }
    it { is_expected.to have_db_column(:stage_name).of_type(:string) }
    it { is_expected.to have_db_column(:heat_number).of_type(:integer) }
    it { is_expected.to have_db_column(:scheduled_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:position).of_type(:integer) }
    it { is_expected.to have_db_column(:status).of_type(:string) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index([:competition_id, :position]) }
    it { is_expected.to have_db_index(:status) }
    it { is_expected.to have_db_index(:scheduled_at) }
  end

  describe "default values" do
    it "has default status of scheduled" do
      race = described_class.new
      expect(race.status).to eq("scheduled")
    end

    it "has default position of 0" do
      race = described_class.new
      expect(race.position).to eq(0)
    end
  end

  describe "data integrity" do
    subject(:race) { create(:race) }

    it "requires a competition" do
      race.competition = nil
      expect(race).not_to be_valid
    end

    it "requires a race_type" do
      race.race_type = nil
      expect(race).not_to be_valid
    end

    it "allows nullable scheduled_at (can be set later)" do
      race.scheduled_at = nil
      expect(race).to be_valid
    end

    it "allows nullable heat_number (for single-stage races)" do
      race.heat_number = nil
      expect(race).to be_valid
    end
  end
end