# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Contracts::AuthenticateUser do
  subject(:contract) { described_class.new }

  describe "params schema" do
    context "with valid params" do
      let(:params) { { email: "valid@example.com", password: "password123" } }

      it "is successful" do
        result = contract.call(params)

        expect(result).to be_success
      end

      it "returns the validated params" do
        result = contract.call(params)

        expect(result.to_h).to eq(email: "valid@example.com", password: "password123")
      end
    end

    context "with missing email" do
      let(:params) { { password: "password123" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:email]).to include("is missing")
      end
    end

    context "with missing password" do
      let(:params) { { email: "valid@example.com" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:password]).to include("is missing")
      end
    end

    context "with blank email" do
      let(:params) { { email: "", password: "password123" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:email]).to include("must be filled")
      end
    end

    context "with blank password" do
      let(:params) { { email: "valid@example.com", password: "" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:password]).to include("must be filled")
      end
    end
  end

  describe "email rule" do
    context "with valid email format" do
      let(:params) { { email: "user@example.com", password: "password123" } }

      it "is successful" do
        result = contract.call(params)

        expect(result).to be_success
      end
    end

    context "with invalid email format" do
      let(:params) { { email: "not-an-email", password: "password123" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:email]).to include("must be a valid email address")
      end
    end

    context "with email missing @" do
      let(:params) { { email: "userexample.com", password: "password123" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:email]).to include("must be a valid email address")
      end
    end

    context "with email missing domain" do
      let(:params) { { email: "user@", password: "password123" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:email]).to include("must be a valid email address")
      end
    end
  end

  describe "password rule" do
    context "with password of exactly 8 characters" do
      let(:params) { { email: "valid@example.com", password: "12345678" } }

      it "is successful" do
        result = contract.call(params)

        expect(result).to be_success
      end
    end

    context "with password longer than 8 characters" do
      let(:params) { { email: "valid@example.com", password: "verylongpassword123" } }

      it "is successful" do
        result = contract.call(params)

        expect(result).to be_success
      end
    end

    context "with password shorter than 8 characters" do
      let(:params) { { email: "valid@example.com", password: "short" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:password]).to include("must be at least 8 characters")
      end
    end

    context "with password of 7 characters" do
      let(:params) { { email: "valid@example.com", password: "1234567" } }

      it "is a failure" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:password]).to include("must be at least 8 characters")
      end
    end
  end

  describe "multiple validation errors" do
    context "with invalid email and short password" do
      let(:params) { { email: "invalid", password: "short" } }

      it "returns errors for both fields" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:email]).to be_present
        expect(result.errors[:password]).to be_present
      end
    end

    context "with missing email and blank password" do
      let(:params) { { password: "" } }

      it "returns errors for both fields" do
        result = contract.call(params)

        expect(result).to be_failure
        expect(result.errors[:email]).to be_present
        expect(result.errors[:password]).to be_present
      end
    end
  end

  describe "errors format" do
    let(:params) { { email: "invalid", password: "short" } }

    it "returns errors as a hash" do
      result = contract.call(params)

      expect(result.errors.to_h).to be_a(Hash)
    end

    it "has symbol keys" do
      result = contract.call(params)

      expect(result.errors.to_h.keys).to all(be_a(Symbol))
    end

    it "has array values with error messages" do
      result = contract.call(params)

      expect(result.errors.to_h.values).to all(be_an(Array))
      expect(result.errors.to_h.values.flatten).to all(be_a(String))
    end
  end
end
