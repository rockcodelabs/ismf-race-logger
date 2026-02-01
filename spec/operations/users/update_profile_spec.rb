# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Users::UpdateProfile do
  let(:operation) { described_class.new }
  let(:user) { User.create!(name: "Test User", email_address: "test@example.com", password: "password123", role: create(:role)) }

  describe "#call" do
    context "with valid email update" do
      it "updates the email address" do
        result = operation.call(
          user_id: user.id,
          email: "newemail@example.com"
        )

        expect(result).to be_success
        expect(result.value!.email_address).to eq("newemail@example.com")
        expect(user.reload.email_address).to eq("newemail@example.com")
      end
    end

    context "with valid password update" do
      it "updates the password" do
        result = operation.call(
          user_id: user.id,
          password: "newpassword123",
          password_confirmation: "newpassword123"
        )

        expect(result).to be_success
        expect(user.reload.authenticate("newpassword123")).to eq(user)
      end
    end

    context "with valid PIN update" do
      it "updates the PIN" do
        result = operation.call(
          user_id: user.id,
          pin: "1234",
          pin_confirmation: "1234"
        )

        expect(result).to be_success
        expect(user.reload.authenticate_pin("1234")).to eq(user)
      end
    end

    context "with multiple fields updated" do
      it "updates all provided fields" do
        result = operation.call(
          user_id: user.id,
          email: "updated@example.com",
          password: "newpass456",
          password_confirmation: "newpass456",
          pin: "5678",
          pin_confirmation: "5678"
        )

        expect(result).to be_success
        user.reload
        expect(user.email_address).to eq("updated@example.com")
        expect(user.authenticate("newpass456")).to eq(user)
        expect(user.authenticate_pin("5678")).to eq(user)
      end
    end

    context "with no fields provided" do
      it "succeeds without changing anything" do
        original_email = user.email_address
        result = operation.call(user_id: user.id)

        expect(result).to be_success
        expect(user.reload.email_address).to eq(original_email)
      end
    end

    context "with invalid email format" do
      it "returns validation failure" do
        result = operation.call(
          user_id: user.id,
          email: "not-an-email"
        )

        expect(result).to be_failure
        expect(result.failure).to match([:validation_failed, hash_including(:email)])
      end
    end

    context "with password too short" do
      it "returns validation failure" do
        result = operation.call(
          user_id: user.id,
          password: "short",
          password_confirmation: "short"
        )

        expect(result).to be_failure
        expect(result.failure).to match([:validation_failed, hash_including(:password)])
      end
    end

    context "with password confirmation mismatch" do
      it "returns validation failure" do
        result = operation.call(
          user_id: user.id,
          password: "newpassword123",
          password_confirmation: "different123"
        )

        expect(result).to be_failure
        expect(result.failure).to match([:validation_failed, hash_including(:password_confirmation)])
      end
    end

    context "with PIN not 4 digits" do
      it "returns validation failure" do
        result = operation.call(
          user_id: user.id,
          pin: "123",
          pin_confirmation: "123"
        )

        expect(result).to be_failure
        expect(result.failure).to match([:validation_failed, hash_including(:pin)])
      end
    end

    context "with PIN containing non-digits" do
      it "returns validation failure" do
        result = operation.call(
          user_id: user.id,
          pin: "12ab",
          pin_confirmation: "12ab"
        )

        expect(result).to be_failure
        expect(result.failure).to match([:validation_failed, hash_including(:pin)])
      end
    end

    context "with PIN confirmation mismatch" do
      it "returns validation failure" do
        result = operation.call(
          user_id: user.id,
          pin: "1234",
          pin_confirmation: "5678"
        )

        expect(result).to be_failure
        expect(result.failure).to match([:validation_failed, hash_including(:pin_confirmation)])
      end
    end

    context "with non-existent user" do
      it "returns user not found failure" do
        result = operation.call(
          user_id: 999_999,
          email: "new@example.com"
        )

        expect(result).to be_failure
        expect(result.failure).to eq(:user_not_found)
      end
    end

    context "with email already taken by another user" do
      let!(:other_user) { User.create!(name: "Other User", email_address: "taken@example.com", password: "password123", role: create(:role)) }

      it "returns email taken failure" do
        result = operation.call(
          user_id: user.id,
          email: "taken@example.com"
        )

        expect(result).to be_failure
        expect(result.failure).to eq(:email_taken)
      end
    end

    context "with email unchanged" do
      it "allows updating with the same email" do
        result = operation.call(
          user_id: user.id,
          email: user.email_address
        )

        expect(result).to be_success
      end
    end
  end
end