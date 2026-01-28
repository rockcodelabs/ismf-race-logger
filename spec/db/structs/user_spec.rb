# frozen_string_literal: true

require "rails_helper"

RSpec.describe Structs::User do
  subject(:user) do
    described_class.new(
      id: 1,
      email_address: "test@example.com",
      name: "Test User",
      admin: admin,
      role_name: role_name,
      created_at: Time.current,
      updated_at: Time.current
    )
  end

  let(:admin) { false }
  let(:role_name) { nil }

  describe "attributes" do
    it "has all expected attributes" do
      expect(user.id).to eq(1)
      expect(user.email_address).to eq("test@example.com")
      expect(user.name).to eq("Test User")
      expect(user.admin).to be false
      expect(user.role_name).to be_nil
      expect(user.created_at).to be_a(Time)
      expect(user.updated_at).to be_a(Time)
    end

    it "is immutable" do
      expect { user.instance_variable_set(:@id, 999) }.not_to change { user.id }
    end
  end

  describe "#display_name" do
    context "when name is present" do
      it "returns the name" do
        expect(user.display_name).to eq("Test User")
      end
    end

    context "when name is blank" do
      subject(:user) do
        described_class.new(
          id: 1,
          email_address: "noname@example.com",
          name: "",
          admin: false,
          role_name: nil,
          created_at: Time.current,
          updated_at: Time.current
        )
      end

      it "returns the email prefix" do
        expect(user.display_name).to eq("noname")
      end
    end
  end

  describe "#admin?" do
    context "when admin is true" do
      let(:admin) { true }

      it "returns true" do
        expect(user.admin?).to be true
      end
    end

    context "when admin is false" do
      let(:admin) { false }

      it "returns false" do
        expect(user.admin?).to be false
      end
    end
  end

  describe "role predicates" do
    describe "#var_operator?" do
      context "when role_name is var_operator" do
        let(:role_name) { "var_operator" }

        it "returns true" do
          expect(user.var_operator?).to be true
        end
      end

      context "when role_name is different" do
        let(:role_name) { "national_referee" }

        it "returns false" do
          expect(user.var_operator?).to be false
        end
      end
    end

    describe "#national_referee?" do
      let(:role_name) { "national_referee" }

      it "returns true for national_referee" do
        expect(user.national_referee?).to be true
      end
    end

    describe "#international_referee?" do
      let(:role_name) { "international_referee" }

      it "returns true for international_referee" do
        expect(user.international_referee?).to be true
      end
    end

    describe "#jury_president?" do
      let(:role_name) { "jury_president" }

      it "returns true for jury_president" do
        expect(user.jury_president?).to be true
      end
    end

    describe "#referee_manager?" do
      let(:role_name) { "referee_manager" }

      it "returns true for referee_manager" do
        expect(user.referee_manager?).to be true
      end
    end

    describe "#broadcast_viewer?" do
      let(:role_name) { "broadcast_viewer" }

      it "returns true for broadcast_viewer" do
        expect(user.broadcast_viewer?).to be true
      end
    end

    describe "#referee?" do
      context "when national_referee" do
        let(:role_name) { "national_referee" }

        it "returns true" do
          expect(user.referee?).to be true
        end
      end

      context "when international_referee" do
        let(:role_name) { "international_referee" }

        it "returns true" do
          expect(user.referee?).to be true
        end
      end

      context "when other role" do
        let(:role_name) { "var_operator" }

        it "returns false" do
          expect(user.referee?).to be false
        end
      end
    end

    describe "#has_role?" do
      let(:role_name) { "jury_president" }

      it "returns true for matching role" do
        expect(user.has_role?("jury_president")).to be true
        expect(user.has_role?(:jury_president)).to be true
      end

      it "returns false for non-matching role" do
        expect(user.has_role?("admin")).to be false
      end
    end
  end

  describe "authorization helpers" do
    describe "#can_officialize_incident?" do
      context "when admin" do
        let(:admin) { true }

        it "returns true" do
          expect(user.can_officialize_incident?).to be true
        end
      end

      context "when referee" do
        let(:role_name) { "national_referee" }

        it "returns true" do
          expect(user.can_officialize_incident?).to be true
        end
      end

      context "when referee_manager" do
        let(:role_name) { "referee_manager" }

        it "returns true" do
          expect(user.can_officialize_incident?).to be true
        end
      end

      context "when var_operator" do
        let(:role_name) { "var_operator" }

        it "returns false" do
          expect(user.can_officialize_incident?).to be false
        end
      end
    end

    describe "#can_decide_incident?" do
      context "when admin" do
        let(:admin) { true }

        it "returns true" do
          expect(user.can_decide_incident?).to be true
        end
      end

      context "when referee_manager" do
        let(:role_name) { "referee_manager" }

        it "returns true" do
          expect(user.can_decide_incident?).to be true
        end
      end

      context "when international_referee" do
        let(:role_name) { "international_referee" }

        it "returns true" do
          expect(user.can_decide_incident?).to be true
        end
      end

      context "when national_referee" do
        let(:role_name) { "national_referee" }

        it "returns false" do
          expect(user.can_decide_incident?).to be false
        end
      end
    end

    describe "#can_merge_incidents?" do
      context "when admin" do
        let(:admin) { true }

        it "returns true" do
          expect(user.can_merge_incidents?).to be true
        end
      end

      context "when referee_manager" do
        let(:role_name) { "referee_manager" }

        it "returns true" do
          expect(user.can_merge_incidents?).to be true
        end
      end

      context "when other role" do
        let(:role_name) { "international_referee" }

        it "returns false" do
          expect(user.can_merge_incidents?).to be false
        end
      end
    end

    describe "#can_manage_users?" do
      context "when admin" do
        let(:admin) { true }

        it "returns true" do
          expect(user.can_manage_users?).to be true
        end
      end

      context "when not admin" do
        let(:admin) { false }
        let(:role_name) { "referee_manager" }

        it "returns false" do
          expect(user.can_manage_users?).to be false
        end
      end
    end
  end

  describe "type coercion" do
    it "transforms string keys to symbols" do
      user = described_class.new(
        "id" => 1,
        "email_address" => "string@example.com",
        "name" => "String Keys",
        "admin" => true,
        "role_name" => "admin",
        "created_at" => Time.current,
        "updated_at" => Time.current
      )

      expect(user.id).to eq(1)
      expect(user.email_address).to eq("string@example.com")
    end
  end
end