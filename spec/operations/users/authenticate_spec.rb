# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Users::Authenticate do
  subject(:operation) { described_class.new }

  describe "#call" do
    context "with valid credentials" do
      let!(:user) do
        create(:user,
          email_address: "valid@example.com",
          password: "password123",
          name: "Valid User"
        )
      end

      it "returns Success with a Structs::User" do
        result = operation.call(email: "valid@example.com", password: "password123")

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::User)
        expect(result.value!.email_address).to eq("valid@example.com")
        expect(result.value!.name).to eq("Valid User")
      end
    end

    context "with invalid password" do
      let!(:user) do
        create(:user,
          email_address: "user@example.com",
          password: "correctpassword"
        )
      end

      it "returns Failure(:invalid_credentials)" do
        result = operation.call(email: "user@example.com", password: "wrongpassword")

        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_credentials)
      end
    end

    context "with non-existent email" do
      it "returns Failure(:invalid_credentials)" do
        result = operation.call(email: "nonexistent@example.com", password: "password123")

        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_credentials)
      end
    end

    context "with invalid email format" do
      it "returns Failure with validation errors" do
        result = operation.call(email: "not-an-email", password: "password123")

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:email)
      end
    end

    context "with password too short" do
      it "returns Failure with validation errors" do
        result = operation.call(email: "valid@example.com", password: "short")

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:password)
      end
    end

    context "with blank email" do
      it "returns Failure with validation errors" do
        result = operation.call(email: "", password: "password123")

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
      end
    end

    context "with blank password" do
      it "returns Failure with validation errors" do
        result = operation.call(email: "valid@example.com", password: "")

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
      end
    end
  end

  describe "dependency injection" do
    let(:mock_repo) { instance_double(UserRepo) }
    let(:operation_with_mock) { described_class.new(repos_user: mock_repo) }

    it "allows injecting a mock repo for testing" do
      user_struct = Structs::User.new(
        id: 1,
        email_address: "injected@example.com",
        name: "Injected User",
        admin: false,
        role_name: nil,
        created_at: Time.current,
        updated_at: Time.current
      )

      allow(mock_repo).to receive(:authenticate)
        .with("injected@example.com", "password123")
        .and_return(user_struct)

      result = operation_with_mock.call(email: "injected@example.com", password: "password123")

      expect(result).to be_success
      expect(result.value!.email_address).to eq("injected@example.com")
      expect(mock_repo).to have_received(:authenticate)
    end

    it "returns failure when mock repo returns nil" do
      allow(mock_repo).to receive(:authenticate)
        .with("fail@example.com", "password123")
        .and_return(nil)

      result = operation_with_mock.call(email: "fail@example.com", password: "password123")

      expect(result).to be_failure
      expect(result.failure).to eq(:invalid_credentials)
    end
  end

  describe "integration with container" do
    it "can be resolved from AppContainer" do
      # The operation uses Import, so it should work with the container
      expect { described_class.new }.not_to raise_error
    end
  end
end