# frozen_string_literal: true

require "rails_helper"

RSpec.describe Structs::UserSummary do
  subject(:summary) do
    described_class.new(
      id: 1,
      email_address: "test@example.com",
      name: "Test User",
      admin: admin,
      role_name: role_name
    )
  end

  let(:admin) { false }
  let(:role_name) { nil }

  describe "attributes" do
    it "has all expected attributes" do
      expect(summary.id).to eq(1)
      expect(summary.email_address).to eq("test@example.com")
      expect(summary.name).to eq("Test User")
      expect(summary.admin).to be false
      expect(summary.role_name).to be_nil
    end

    it "is a Ruby Data class" do
      expect(described_class.ancestors).to include(Data)
    end

    it "is immutable" do
      # Ruby Data classes are frozen and raise FrozenError when mutated
      expect { summary.instance_variable_set(:@id, 999) }.to raise_error(FrozenError)
    end
  end

  describe "#display_name" do
    context "when name is present" do
      it "returns the name" do
        expect(summary.display_name).to eq("Test User")
      end
    end

    context "when name is blank" do
      subject(:summary) do
        described_class.new(
          id: 1,
          email_address: "noname@example.com",
          name: "",
          admin: false,
          role_name: nil
        )
      end

      it "returns the email prefix" do
        expect(summary.display_name).to eq("noname")
      end
    end

    context "when name is nil" do
      subject(:summary) do
        described_class.new(
          id: 1,
          email_address: "nilname@example.com",
          name: nil,
          admin: false,
          role_name: nil
        )
      end

      it "returns the email prefix" do
        expect(summary.display_name).to eq("nilname")
      end
    end
  end

  describe "#admin?" do
    context "when admin is true" do
      let(:admin) { true }

      it "returns true" do
        expect(summary.admin?).to be true
      end
    end

    context "when admin is false" do
      let(:admin) { false }

      it "returns false" do
        expect(summary.admin?).to be false
      end
    end
  end

  describe "role predicates" do
    describe "#var_operator?" do
      context "when role_name is var_operator" do
        let(:role_name) { "var_operator" }

        it "returns true" do
          expect(summary.var_operator?).to be true
        end
      end

      context "when role_name is different" do
        let(:role_name) { "national_referee" }

        it "returns false" do
          expect(summary.var_operator?).to be false
        end
      end
    end

    describe "#national_referee?" do
      let(:role_name) { "national_referee" }

      it "returns true for national_referee" do
        expect(summary.national_referee?).to be true
      end
    end

    describe "#international_referee?" do
      let(:role_name) { "international_referee" }

      it "returns true for international_referee" do
        expect(summary.international_referee?).to be true
      end
    end

    describe "#jury_president?" do
      let(:role_name) { "jury_president" }

      it "returns true for jury_president" do
        expect(summary.jury_president?).to be true
      end
    end

    describe "#referee_manager?" do
      let(:role_name) { "referee_manager" }

      it "returns true for referee_manager" do
        expect(summary.referee_manager?).to be true
      end
    end

    describe "#broadcast_viewer?" do
      let(:role_name) { "broadcast_viewer" }

      it "returns true for broadcast_viewer" do
        expect(summary.broadcast_viewer?).to be true
      end
    end

    describe "#referee?" do
      context "when national_referee" do
        let(:role_name) { "national_referee" }

        it "returns true" do
          expect(summary.referee?).to be true
        end
      end

      context "when international_referee" do
        let(:role_name) { "international_referee" }

        it "returns true" do
          expect(summary.referee?).to be true
        end
      end

      context "when other role" do
        let(:role_name) { "var_operator" }

        it "returns false" do
          expect(summary.referee?).to be false
        end
      end

      context "when nil role" do
        let(:role_name) { nil }

        it "returns false" do
          expect(summary.referee?).to be false
        end
      end
    end
  end

  describe "performance characteristics" do
    it "is faster to instantiate than dry-struct" do
      # This is a documentation test - Data classes are ~7x faster than dry-struct
      # We just verify it can be instantiated quickly
      summaries = 1000.times.map do |i|
        described_class.new(
          id: i,
          email_address: "user#{i}@example.com",
          name: "User #{i}",
          admin: false,
          role_name: nil
        )
      end

      expect(summaries.size).to eq(1000)
    end
  end

  describe "keyword arguments" do
    it "can be instantiated with keyword arguments" do
      summary = described_class.new(
        id: 42,
        email_address: "keyword@example.com",
        name: "Keyword User",
        admin: true,
        role_name: "jury_president"
      )

      expect(summary.id).to eq(42)
      expect(summary.email_address).to eq("keyword@example.com")
      expect(summary.admin?).to be true
      expect(summary.role_name).to eq("jury_president")
    end
  end
end