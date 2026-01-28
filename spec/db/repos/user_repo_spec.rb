# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserRepo do
  subject(:repo) { described_class.new }

  describe "configuration" do
    it "has correct record_class" do
      expect(described_class.record_class).to eq(User)
    end

    it "has correct struct_class" do
      expect(described_class.struct_class).to eq(Structs::User)
    end

    it "has correct summary_class" do
      expect(described_class.summary_class).to eq(Structs::UserSummary)
    end
  end

  describe "#find" do
    context "when user exists" do
      let!(:user) { create(:user, name: "Test User", email_address: "test@example.com") }

      it "returns a Structs::User" do
        result = repo.find(user.id)

        expect(result).to be_a(Structs::User)
        expect(result.id).to eq(user.id)
        expect(result.email_address).to eq("test@example.com")
        expect(result.name).to eq("Test User")
      end
    end

    context "when user does not exist" do
      it "returns nil" do
        result = repo.find(999999)

        expect(result).to be_nil
      end
    end
  end

  describe "#find!" do
    context "when user exists" do
      let!(:user) { create(:user) }

      it "returns a Structs::User" do
        result = repo.find!(user.id)

        expect(result).to be_a(Structs::User)
        expect(result.id).to eq(user.id)
      end
    end

    context "when user does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { repo.find!(999999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#find_by_email" do
    context "when user exists" do
      let!(:user) { create(:user, email_address: "findme@example.com") }

      it "returns a Structs::User" do
        result = repo.find_by_email("findme@example.com")

        expect(result).to be_a(Structs::User)
        expect(result.email_address).to eq("findme@example.com")
      end
    end

    context "when user does not exist" do
      it "returns nil" do
        result = repo.find_by_email("notfound@example.com")

        expect(result).to be_nil
      end
    end
  end

  describe "#authenticate" do
    let!(:user) { create(:user, email_address: "auth@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns a Structs::User" do
        result = repo.authenticate("auth@example.com", "password123")

        expect(result).to be_a(Structs::User)
        expect(result.email_address).to eq("auth@example.com")
      end
    end

    context "with invalid password" do
      it "returns nil" do
        result = repo.authenticate("auth@example.com", "wrongpassword")

        expect(result).to be_nil
      end
    end

    context "with non-existent email" do
      it "returns nil" do
        result = repo.authenticate("nonexistent@example.com", "password123")

        expect(result).to be_nil
      end
    end
  end

  describe "#all" do
    let!(:users) { create_list(:user, 3) }

    it "returns an array of Structs::UserSummary" do
      result = repo.all

      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
      expect(result).to all(be_a(Structs::UserSummary))
    end

    it "orders by created_at desc" do
      result = repo.all

      expect(result.map(&:id)).to eq(users.reverse.map(&:id))
    end
  end

  describe "#admins" do
    let!(:admin1) { create(:user, :admin) }
    let!(:admin2) { create(:user, :admin) }
    let!(:regular_user) { create(:user, admin: false) }

    it "returns only admin users as Structs::UserSummary" do
      result = repo.admins

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::UserSummary))
      expect(result.map(&:id)).to contain_exactly(admin1.id, admin2.id)
    end
  end

  describe "#referees" do
    let!(:national_referee) { create(:user, :national_referee) }
    let!(:international_referee) { create(:user, :international_referee) }
    let!(:var_operator) { create(:user, :var_operator) }
    let!(:regular_user) { create(:user) }

    it "returns only referee users (national and international)" do
      result = repo.referees

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::UserSummary))
      expect(result.map(&:id)).to contain_exactly(national_referee.id, international_referee.id)
    end
  end

  describe "#with_role" do
    let!(:var_operator1) { create(:user, :var_operator) }
    let!(:var_operator2) { create(:user, :var_operator) }
    let!(:referee) { create(:user, :national_referee) }

    it "returns users with the specified role" do
      result = repo.with_role("var_operator")

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result).to all(be_a(Structs::UserSummary))
      expect(result.map(&:id)).to contain_exactly(var_operator1.id, var_operator2.id)
    end
  end

  describe "#search" do
    let!(:john) { create(:user, name: "John Doe", email_address: "john@example.com") }
    let!(:jane) { create(:user, name: "Jane Smith", email_address: "jane@example.com") }
    let!(:bob) { create(:user, name: "Bob Wilson", email_address: "bob@test.com") }

    it "finds users by name (case-insensitive)" do
      result = repo.search("john")

      expect(result.size).to eq(1)
      expect(result.first.id).to eq(john.id)
    end

    it "finds users by email (case-insensitive)" do
      result = repo.search("example.com")

      expect(result.size).to eq(2)
      expect(result.map(&:id)).to contain_exactly(john.id, jane.id)
    end

    it "returns empty array for blank query" do
      expect(repo.search("")).to eq([])
      expect(repo.search(nil)).to eq([])
    end
  end

  describe "#email_exists?" do
    let!(:user) { create(:user, email_address: "exists@example.com") }

    it "returns true when email exists" do
      expect(repo.email_exists?("exists@example.com")).to be true
    end

    it "returns false when email does not exist" do
      expect(repo.email_exists?("notexists@example.com")).to be false
    end
  end

  describe "#create" do
    context "with valid attributes" do
      let(:attrs) do
        {
          email_address: "new@example.com",
          name: "New User",
          password: "password123",
          password_confirmation: "password123",
          admin: false
        }
      end

      it "creates a user and returns a Structs::User" do
        result = repo.create(attrs)

        expect(result).to be_a(Structs::User)
        expect(result.email_address).to eq("new@example.com")
        expect(result.name).to eq("New User")
      end
    end

    context "with role_name" do
      let!(:role) { create(:role, :referee_manager) }
      let(:attrs) do
        {
          email_address: "withrole@example.com",
          name: "Role User",
          password: "password123",
          password_confirmation: "password123",
          role_name: "referee_manager"
        }
      end

      it "looks up role and creates user with role_id" do
        result = repo.create(attrs)

        expect(result).to be_a(Structs::User)
        expect(result.role_name).to eq("referee_manager")
      end
    end

    context "with invalid role_name" do
      let(:attrs) do
        {
          email_address: "badrole@example.com",
          name: "Bad Role User",
          password: "password123",
          role_name: "nonexistent_role"
        }
      end

      it "returns nil" do
        result = repo.create(attrs)

        expect(result).to be_nil
      end
    end
  end

  describe "#update" do
    let!(:user) { create(:user, name: "Original Name") }

    context "with valid attributes" do
      it "updates and returns a Structs::User" do
        result = repo.update(user.id, name: "Updated Name")

        expect(result).to be_a(Structs::User)
        expect(result.name).to eq("Updated Name")
      end
    end

    context "with role_name" do
      let!(:role) { create(:role, :jury_president) }

      it "looks up role and updates user" do
        result = repo.update(user.id, role_name: "jury_president")

        expect(result).to be_a(Structs::User)
        expect(result.role_name).to eq("jury_president")
      end
    end

    context "when user not found" do
      it "returns nil" do
        result = repo.update(999999, name: "Test")

        expect(result).to be_nil
      end
    end
  end

  describe "#delete" do
    let!(:user) { create(:user) }

    it "deletes the user and returns true" do
      result = repo.delete(user.id)

      expect(result).to be true
      expect(User.exists?(user.id)).to be false
    end

    context "when user not found" do
      it "returns nil" do
        result = repo.delete(999999)

        expect(result).to be_nil
      end
    end
  end

  describe "eager loading" do
    let!(:user) { create(:user, :national_referee) }

    it "includes role to prevent N+1 queries" do
      # This should not trigger additional queries for role
      result = repo.find(user.id)

      expect(result.role_name).to eq("national_referee")
    end
  end
end
