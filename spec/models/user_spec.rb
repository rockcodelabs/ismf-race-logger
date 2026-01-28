# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe "associations" do
    it { is_expected.to belong_to(:role).optional }
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:magic_links).dependent(:destroy) }
  end

  describe "has_secure_password" do
    it "authenticates with correct password" do
      user = described_class.new(
        email_address: "test@example.com",
        name: "Test User",
        password: "password123",
        password_confirmation: "password123"
      )
      user.save!

      expect(user.authenticate("password123")).to eq(user)
    end

    it "does not authenticate with incorrect password" do
      user = described_class.new(
        email_address: "test@example.com",
        name: "Test User",
        password: "password123",
        password_confirmation: "password123"
      )
      user.save!

      expect(user.authenticate("wrongpassword")).to be false
    end
  end

  describe "model is thin" do
    it "has no scopes defined" do
      # User model should have no scopes - all query logic belongs in UserRepo
      # This test documents that expectation
      scope_methods = described_class.methods.grep(/^scope_/)
      
      # ActiveRecord defines some internal scope methods, but we shouldn't have custom ones
      # Our custom scopes would show up differently, so we check the class doesn't respond to common scope names
      expect(described_class).not_to respond_to(:ordered)
      expect(described_class).not_to respond_to(:admins)
      expect(described_class).not_to respond_to(:by_email)
      expect(described_class).not_to respond_to(:with_role)
      expect(described_class).not_to respond_to(:referees)
    end

    it "has no business logic methods" do
      user = described_class.new

      # These methods should NOT exist on the model - they belong in Structs::User
      expect(user).not_to respond_to(:display_name)
      expect(user).not_to respond_to(:admin?)
      expect(user).not_to respond_to(:referee?)
      expect(user).not_to respond_to(:can_officialize_incident?)
      expect(user).not_to respond_to(:can_decide_incident?)
      expect(user).not_to respond_to(:can_manage_users?)
    end

    it "has no class-level authenticate_by method" do
      # Authentication logic belongs in UserRepo#authenticate
      expect(described_class).not_to respond_to(:authenticate_by)
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:email_address).of_type(:string) }
    it { is_expected.to have_db_column(:name).of_type(:string) }
    it { is_expected.to have_db_column(:password_digest).of_type(:string) }
    it { is_expected.to have_db_column(:admin).of_type(:boolean).with_options(default: false) }
    it { is_expected.to have_db_column(:role_id).of_type(:integer) }
    it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }
  end

  describe "database indexes" do
    it { is_expected.to have_db_index(:email_address).unique }
    it { is_expected.to have_db_index(:role_id) }
  end
end