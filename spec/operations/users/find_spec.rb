# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Users::Find do
  subject(:operation) { described_class.new }

  describe "#call" do
    context "when user exists" do
      let!(:user) do
        create(:user,
          email_address: "findme@example.com",
          name: "Find Me User"
        )
      end

      it "returns Success with a Structs::User" do
        result = operation.call(id: user.id)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::User)
        expect(result.value!.id).to eq(user.id)
        expect(result.value!.email_address).to eq("findme@example.com")
        expect(result.value!.name).to eq("Find Me User")
      end
    end

    context "when user does not exist" do
      it "returns Failure(:not_found)" do
        result = operation.call(id: 999999)

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end
    end
  end

  describe "#by_email" do
    context "when user exists" do
      let!(:user) do
        create(:user,
          email_address: "byemail@example.com",
          name: "By Email User"
        )
      end

      it "returns Success with a Structs::User" do
        result = operation.by_email("byemail@example.com")

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::User)
        expect(result.value!.email_address).to eq("byemail@example.com")
      end
    end

    context "when user does not exist" do
      it "returns Failure(:not_found)" do
        result = operation.by_email("nonexistent@example.com")

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end
    end
  end

  describe "dependency injection" do
    let(:mock_repo) { instance_double(UserRepo) }
    let(:operation_with_mock) { described_class.new(repos_user: mock_repo) }

    describe "#call with mock" do
      it "uses the injected repo" do
        user_struct = Structs::User.new(
          id: 42,
          email_address: "mock@example.com",
          name: "Mock User",
          admin: false,
          role_name: nil,
          created_at: Time.current,
          updated_at: Time.current
        )

        allow(mock_repo).to receive(:find).with(42).and_return(user_struct)

        result = operation_with_mock.call(id: 42)

        expect(result).to be_success
        expect(result.value!.id).to eq(42)
        expect(mock_repo).to have_received(:find).with(42)
      end

      it "returns failure when mock repo returns nil" do
        allow(mock_repo).to receive(:find).with(999).and_return(nil)

        result = operation_with_mock.call(id: 999)

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end
    end

    describe "#by_email with mock" do
      it "uses the injected repo" do
        user_struct = Structs::User.new(
          id: 1,
          email_address: "injected@example.com",
          name: "Injected User",
          admin: true,
          role_name: "referee_manager",
          created_at: Time.current,
          updated_at: Time.current
        )

        allow(mock_repo).to receive(:find_by_email)
          .with("injected@example.com")
          .and_return(user_struct)

        result = operation_with_mock.by_email("injected@example.com")

        expect(result).to be_success
        expect(result.value!.email_address).to eq("injected@example.com")
        expect(result.value!.admin?).to be true
        expect(mock_repo).to have_received(:find_by_email)
      end
    end
  end

  describe "returned struct attributes" do
    let!(:role) { create(:role, :international_referee) }
    let!(:user) do
      create(:user,
        email_address: "detailed@example.com",
        name: "Detailed User",
        admin: true,
        role: role
      )
    end

    it "includes all user attributes in the struct" do
      result = operation.call(id: user.id)

      expect(result).to be_success

      user_struct = result.value!
      expect(user_struct.id).to eq(user.id)
      expect(user_struct.email_address).to eq("detailed@example.com")
      expect(user_struct.name).to eq("Detailed User")
      expect(user_struct.admin).to be true
      expect(user_struct.role_name).to eq("international_referee")
      expect(user_struct.created_at).to be_present
      expect(user_struct.updated_at).to be_present
    end

    it "allows calling business logic methods on the struct" do
      result = operation.call(id: user.id)
      user_struct = result.value!

      expect(user_struct.admin?).to be true
      expect(user_struct.international_referee?).to be true
      expect(user_struct.referee?).to be true
      expect(user_struct.can_decide_incident?).to be true
      expect(user_struct.display_name).to eq("Detailed User")
    end
  end
end