# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Users::List do
  subject(:operation) { described_class.new }

  describe "#call" do
    let!(:user1) { create(:user, name: "User One") }
    let!(:user2) { create(:user, name: "User Two") }
    let!(:user3) { create(:user, name: "User Three") }

    it "returns Success with array of Structs::UserSummary" do
      result = operation.call

      expect(result).to be_success
      expect(result.value!).to be_an(Array)
      expect(result.value!.size).to eq(3)
      expect(result.value!).to all(be_a(Structs::UserSummary))
    end

    it "returns users ordered by created_at desc" do
      result = operation.call

      expect(result.value!.map(&:id)).to eq([user3.id, user2.id, user1.id])
    end
  end

  describe "#admins" do
    let!(:admin1) { create(:user, :admin, name: "Admin One") }
    let!(:admin2) { create(:user, :admin, name: "Admin Two") }
    let!(:regular_user) { create(:user, admin: false, name: "Regular User") }

    it "returns Success with only admin users" do
      result = operation.admins

      expect(result).to be_success
      expect(result.value!.size).to eq(2)
      expect(result.value!.map(&:id)).to contain_exactly(admin1.id, admin2.id)
    end

    it "returns Structs::UserSummary objects" do
      result = operation.admins

      expect(result.value!).to all(be_a(Structs::UserSummary))
      expect(result.value!.first.admin?).to be true
    end
  end

  describe "#referees" do
    let!(:national_referee) { create(:user, :national_referee, name: "National Ref") }
    let!(:international_referee) { create(:user, :international_referee, name: "International Ref") }
    let!(:var_operator) { create(:user, :var_operator, name: "VAR Op") }
    let!(:regular_user) { create(:user, name: "Regular User") }

    it "returns Success with only referee users (national and international)" do
      result = operation.referees

      expect(result).to be_success
      expect(result.value!.size).to eq(2)
      expect(result.value!.map(&:id)).to contain_exactly(national_referee.id, international_referee.id)
    end

    it "returns Structs::UserSummary with referee role" do
      result = operation.referees

      expect(result.value!).to all(be_a(Structs::UserSummary))
      expect(result.value!).to all(satisfy { |u| u.referee? })
    end
  end

  describe "#with_role" do
    let!(:var_operator1) { create(:user, :var_operator, name: "VAR Op 1") }
    let!(:var_operator2) { create(:user, :var_operator, name: "VAR Op 2") }
    let!(:referee) { create(:user, :national_referee, name: "Referee") }
    let!(:jury_president) { create(:user, :jury_president, name: "Jury Pres") }

    it "returns Success with users of specified role" do
      result = operation.with_role("var_operator")

      expect(result).to be_success
      expect(result.value!.size).to eq(2)
      expect(result.value!.map(&:id)).to contain_exactly(var_operator1.id, var_operator2.id)
    end

    it "returns empty array when no users have the role" do
      result = operation.with_role("broadcast_viewer")

      expect(result).to be_success
      expect(result.value!).to eq([])
    end

    it "works with different roles" do
      result = operation.with_role("jury_president")

      expect(result).to be_success
      expect(result.value!.size).to eq(1)
      expect(result.value!.first.id).to eq(jury_president.id)
    end
  end

  describe "#search" do
    let!(:john) { create(:user, name: "John Doe", email_address: "john@example.com") }
    let!(:jane) { create(:user, name: "Jane Smith", email_address: "jane@example.com") }
    let!(:bob) { create(:user, name: "Bob Wilson", email_address: "bob@test.org") }

    it "returns Success with users matching name" do
      result = operation.search("john")

      expect(result).to be_success
      expect(result.value!.size).to eq(1)
      expect(result.value!.first.id).to eq(john.id)
    end

    it "returns Success with users matching email domain" do
      result = operation.search("example.com")

      expect(result).to be_success
      expect(result.value!.size).to eq(2)
      expect(result.value!.map(&:id)).to contain_exactly(john.id, jane.id)
    end

    it "is case-insensitive" do
      result = operation.search("JOHN")

      expect(result).to be_success
      expect(result.value!.size).to eq(1)
      expect(result.value!.first.id).to eq(john.id)
    end

    it "returns empty array for no matches" do
      result = operation.search("nonexistent")

      expect(result).to be_success
      expect(result.value!).to eq([])
    end

    it "returns empty array for blank query" do
      result = operation.search("")

      expect(result).to be_success
      expect(result.value!).to eq([])
    end

    it "returns empty array for nil query" do
      result = operation.search(nil)

      expect(result).to be_success
      expect(result.value!).to eq([])
    end
  end

  describe "dependency injection" do
    let(:mock_repo) { instance_double(UserRepo) }
    let(:operation_with_mock) { described_class.new(repos_user: mock_repo) }

    describe "#call with mock" do
      it "uses the injected repo" do
        summaries = [
          Structs::UserSummary.new(id: 1, email_address: "a@b.com", name: "A", admin: false, role_name: nil),
          Structs::UserSummary.new(id: 2, email_address: "b@c.com", name: "B", admin: true, role_name: nil)
        ]

        allow(mock_repo).to receive(:all).and_return(summaries)

        result = operation_with_mock.call

        expect(result).to be_success
        expect(result.value!.size).to eq(2)
        expect(mock_repo).to have_received(:all)
      end
    end

    describe "#admins with mock" do
      it "uses the injected repo" do
        admin_summaries = [
          Structs::UserSummary.new(id: 1, email_address: "admin@b.com", name: "Admin", admin: true, role_name: nil)
        ]

        allow(mock_repo).to receive(:admins).and_return(admin_summaries)

        result = operation_with_mock.admins

        expect(result).to be_success
        expect(result.value!.size).to eq(1)
        expect(result.value!.first.admin?).to be true
        expect(mock_repo).to have_received(:admins)
      end
    end

    describe "#search with mock" do
      it "uses the injected repo" do
        search_results = [
          Structs::UserSummary.new(id: 5, email_address: "found@test.com", name: "Found", admin: false, role_name: nil)
        ]

        allow(mock_repo).to receive(:search).with("test").and_return(search_results)

        result = operation_with_mock.search("test")

        expect(result).to be_success
        expect(result.value!.size).to eq(1)
        expect(mock_repo).to have_received(:search).with("test")
      end
    end
  end

  describe "returned struct attributes" do
    let!(:role) { create(:role, :referee_manager) }
    let!(:user) do
      create(:user,
        email_address: "summary@example.com",
        name: "Summary User",
        admin: true,
        role: role
      )
    end

    it "includes expected attributes in UserSummary" do
      result = operation.call

      expect(result).to be_success

      summary = result.value!.find { |u| u.id == user.id }
      expect(summary).to be_present
      expect(summary.id).to eq(user.id)
      expect(summary.email_address).to eq("summary@example.com")
      expect(summary.name).to eq("Summary User")
      expect(summary.admin).to be true
      expect(summary.role_name).to eq("referee_manager")
    end

    it "allows calling business logic methods on the summary" do
      result = operation.call

      summary = result.value!.find { |u| u.id == user.id }
      expect(summary.admin?).to be true
      expect(summary.referee_manager?).to be true
      expect(summary.display_name).to eq("Summary User")
    end
  end
end