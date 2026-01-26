# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:magic_links).dependent(:destroy) }
    it { is_expected.to belong_to(:role).optional }
  end

  describe 'validations' do
    subject { create(:user) }

    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to have_secure_password }
  end

  describe 'normalizations' do
    it 'normalizes email_address to lowercase and strips whitespace' do
      user = create(:user, email_address: '  TEST@EXAMPLE.COM  ')
      expect(user.email_address).to eq('test@example.com')
    end
  end

  describe 'scopes' do
    describe '.admins' do
      let!(:admin) { create(:user, :admin) }
      let!(:regular_user) { create(:user) }

      it 'returns only admin users' do
        expect(described_class.admins).to contain_exactly(admin)
      end
    end

    describe '.referees' do
      let!(:national_ref) { create(:user, :national_referee) }
      let!(:international_ref) { create(:user, :international_referee) }
      let!(:var_op) { create(:user, :var_operator) }
      let!(:no_role_user) { create(:user) }

      it 'returns users with referee roles' do
        expect(described_class.referees).to contain_exactly(national_ref, international_ref)
      end
    end

    describe '.var_operators' do
      let!(:var_op) { create(:user, :var_operator) }
      let!(:national_ref) { create(:user, :national_referee) }
      let!(:no_role_user) { create(:user) }

      it 'returns users with var_operator role' do
        expect(described_class.var_operators).to contain_exactly(var_op)
      end
    end

    describe '.with_role' do
      let!(:jury) { create(:user, :jury_president) }
      let!(:manager) { create(:user, :referee_manager) }

      it 'returns users with the specified role' do
        expect(described_class.with_role('jury_president')).to contain_exactly(jury)
        expect(described_class.with_role('referee_manager')).to contain_exactly(manager)
      end
    end
  end

  describe '#admin?' do
    it 'returns true for admin users' do
      user = build(:user, :admin)
      expect(user.admin?).to be true
    end

    it 'returns false for non-admin users' do
      user = build(:user, admin: false)
      expect(user.admin?).to be false
    end
  end

  describe '#display_name' do
    it 'returns the name if present' do
      user = build(:user, name: 'John Doe', email_address: 'john@example.com')
      expect(user.display_name).to eq('John Doe')
    end

    it 'returns the email prefix if name is blank' do
      user = build(:user, name: '', email_address: 'john@example.com')
      # Validation will fail, but we're testing the method behavior
      user.name = ''
      expect(user.display_name).to eq('john')
    end
  end

  describe '#generate_magic_link!' do
    let(:user) { create(:user) }

    it 'creates a new magic link' do
      expect { user.generate_magic_link! }.to change { user.magic_links.count }.by(1)
    end

    it 'returns the created magic link' do
      magic_link = user.generate_magic_link!
      expect(magic_link).to be_a(MagicLink)
      expect(magic_link).to be_persisted
    end
  end

  describe 'role check methods' do
    describe '#var_operator?' do
      it 'returns true for var_operator role' do
        user = build(:user, :var_operator)
        expect(user.var_operator?).to be true
      end

      it 'returns false for other roles' do
        user = build(:user, :national_referee)
        expect(user.var_operator?).to be false
      end

      it 'returns false for users without a role' do
        user = build(:user, role: nil)
        expect(user.var_operator?).to be false
      end
    end

    describe '#national_referee?' do
      it 'returns true for national_referee role' do
        user = build(:user, :national_referee)
        expect(user.national_referee?).to be true
      end

      it 'returns false for other roles' do
        user = build(:user, :international_referee)
        expect(user.national_referee?).to be false
      end
    end

    describe '#international_referee?' do
      it 'returns true for international_referee role' do
        user = build(:user, :international_referee)
        expect(user.international_referee?).to be true
      end

      it 'returns false for other roles' do
        user = build(:user, :national_referee)
        expect(user.international_referee?).to be false
      end
    end

    describe '#jury_president?' do
      it 'returns true for jury_president role' do
        user = build(:user, :jury_president)
        expect(user.jury_president?).to be true
      end

      it 'returns false for other roles' do
        user = build(:user, :var_operator)
        expect(user.jury_president?).to be false
      end
    end

    describe '#referee_manager?' do
      it 'returns true for referee_manager role' do
        user = build(:user, :referee_manager)
        expect(user.referee_manager?).to be true
      end

      it 'returns false for other roles' do
        user = build(:user, :var_operator)
        expect(user.referee_manager?).to be false
      end
    end

    describe '#broadcast_viewer?' do
      it 'returns true for broadcast_viewer role' do
        user = build(:user, :broadcast_viewer)
        expect(user.broadcast_viewer?).to be true
      end

      it 'returns false for other roles' do
        user = build(:user, :var_operator)
        expect(user.broadcast_viewer?).to be false
      end
    end

    describe '#referee?' do
      it 'returns true for national_referee' do
        user = build(:user, :national_referee)
        expect(user.referee?).to be true
      end

      it 'returns true for international_referee' do
        user = build(:user, :international_referee)
        expect(user.referee?).to be true
      end

      it 'returns false for non-referee roles' do
        user = build(:user, :var_operator)
        expect(user.referee?).to be false
      end

      it 'returns false for users without a role' do
        user = build(:user, role: nil)
        expect(user.referee?).to be false
      end
    end

    describe '#has_role?' do
      it 'returns true when user has the specified role' do
        user = build(:user, :var_operator)
        expect(user.has_role?(:var_operator)).to be true
        expect(user.has_role?('var_operator')).to be true
      end

      it 'returns false when user has a different role' do
        user = build(:user, :var_operator)
        expect(user.has_role?(:national_referee)).to be false
      end

      it 'returns false when user has no role' do
        user = build(:user, role: nil)
        expect(user.has_role?(:var_operator)).to be false
      end
    end
  end

  describe 'email format validation' do
    it 'accepts valid email addresses' do
      valid_emails = %w[
        user@example.com
        USER@foo.COM
        first.last@domain.co.uk
        user+tag@example.org
      ]

      valid_emails.each do |email|
        user = build(:user, email_address: email)
        expect(user).to be_valid, "Expected #{email} to be valid"
      end
    end

    it 'rejects invalid email addresses' do
      invalid_emails = %w[
        plainaddress
        @missinglocal.com
        user@
        user@.com
      ]

      invalid_emails.each do |email|
        user = build(:user, email_address: email)
        expect(user).not_to be_valid, "Expected #{email} to be invalid"
      end
    end
  end
end