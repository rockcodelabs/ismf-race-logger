# frozen_string_literal: true

require "rails_helper"

RSpec.describe Competition do
  describe "associations" do
    it { is_expected.to have_many(:races).dependent(:destroy) }
    it { is_expected.to have_one_attached(:logo) }
  end

  describe "model is thin" do
    it "has no scopes defined" do
      # Competition model should have no scopes - all query logic belongs in CompetitionRepo
      expect(described_class).not_to respond_to(:ordered)
      expect(described_class).not_to respond_to(:ongoing)
      expect(described_class).not_to respond_to(:upcoming)
      expect(described_class).not_to respond_to(:past)
      expect(described_class).not_to respond_to(:by_country)
      expect(described_class).not_to respond_to(:by_city)
    end

    it "has no business logic methods" do
      competition = described_class.new

      # These methods should NOT exist on the model - they belong in Structs::Competition
      expect(competition).not_to respond_to(:display_name)
      expect(competition).not_to respond_to(:date_range)
      expect(competition).not_to respond_to(:ongoing?)
      expect(competition).not_to respond_to(:upcoming?)
      expect(competition).not_to respond_to(:past?)
      expect(competition).not_to respond_to(:status)
      expect(competition).not_to respond_to(:country_name)
      expect(competition).not_to respond_to(:country_flag_emoji)
    end

    it "has no custom class methods beyond Rails defaults" do
      # The model should only have Rails-provided methods
      # All custom queries belong in CompetitionRepo
      custom_methods = described_class.methods - ApplicationRecord.methods
      business_logic_methods = custom_methods.grep(/^(find_by_|search|filter|status)/)
      
      expect(business_logic_methods).to be_empty
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:name).of_type(:string) }
    it { is_expected.to have_db_column(:city).of_type(:string) }
    it { is_expected.to have_db_column(:place).of_type(:string) }
    it { is_expected.to have_db_column(:country).of_type(:string) }
    it { is_expected.to have_db_column(:description).of_type(:text) }
    it { is_expected.to have_db_column(:start_date).of_type(:date) }
    it { is_expected.to have_db_column(:end_date).of_type(:date) }
    it { is_expected.to have_db_column(:webpage_url).of_type(:string) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index(:country) }
    it { is_expected.to have_db_index(:start_date) }
  end
end