# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Infrastructure::Persistence::Records::MagicLinkRecord, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user).class_name('Infrastructure::Persistence::Records::UserRecord') }
  end

  describe 'validations' do
    subject { create(:magic_link) }

    # Note: We test uniqueness but not presence validations because
    # the before_validation callbacks auto-generate token and expires_at
    it { is_expected.to validate_uniqueness_of(:token) }
  end

  describe 'callbacks' do
    describe 'before_validation on create' do
      it 'generates a token if not provided' do
        magic_link = build(:magic_link, token: nil)
        magic_link.valid?
        expect(magic_link.token).to be_present
        expect(magic_link.token.length).to be >= 32
      end

      it 'does not overwrite an existing token' do
        magic_link = build(:magic_link, token: 'custom-token-123')
        magic_link.valid?
        expect(magic_link.token).to eq('custom-token-123')
      end

      it 'sets expiry to 15 minutes from now if not provided' do
        travel_to Time.current do
          magic_link = build(:magic_link, expires_at: nil)
          magic_link.valid?
          expect(magic_link.expires_at).to be_within(1.second).of(15.minutes.from_now)
        end
      end

      it 'does not overwrite an existing expiry' do
        custom_expiry = 1.hour.from_now
        magic_link = build(:magic_link, expires_at: custom_expiry)
        magic_link.valid?
        expect(magic_link.expires_at).to be_within(1.second).of(custom_expiry)
      end
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:valid_link) { create(:magic_link, :valid, user: user) }
    let!(:expired_link) { create(:magic_link, :expired, user: user) }
    let!(:used_link) { create(:magic_link, :used, user: user) }

    describe '.valid' do
      it 'returns only unused and non-expired links' do
        expect(described_class.valid).to contain_exactly(valid_link)
      end
    end

    describe '.expired' do
      it 'returns only expired links' do
        expect(described_class.expired).to contain_exactly(expired_link)
      end
    end

    describe '.used' do
      it 'returns only used links' do
        expect(described_class.used).to contain_exactly(used_link)
      end
    end
  end

  describe '#expired?' do
    it 'returns true when expires_at is in the past' do
      magic_link = build(:magic_link, :expired)
      expect(magic_link.expired?).to be true
    end

    it 'returns false when expires_at is in the future' do
      magic_link = build(:magic_link, :valid)
      expect(magic_link.expired?).to be false
    end
  end

  describe '#used?' do
    it 'returns true when used_at is present' do
      magic_link = build(:magic_link, :used)
      expect(magic_link.used?).to be true
    end

    it 'returns false when used_at is nil' do
      magic_link = build(:magic_link, used_at: nil)
      expect(magic_link.used?).to be false
    end
  end

  describe '#valid_for_use?' do
    it 'returns true when not expired and not used' do
      magic_link = build(:magic_link, :valid)
      expect(magic_link.valid_for_use?).to be true
    end

    it 'returns false when expired' do
      magic_link = build(:magic_link, :expired)
      expect(magic_link.valid_for_use?).to be false
    end

    it 'returns false when used' do
      magic_link = build(:magic_link, :used)
      expect(magic_link.valid_for_use?).to be false
    end

    it 'returns false when both expired and used' do
      magic_link = build(:magic_link, :expired, :used)
      expect(magic_link.valid_for_use?).to be false
    end
  end

  describe '#consume!' do
    context 'when magic link is valid for use' do
      it 'sets used_at to current time' do
        magic_link = create(:magic_link, :valid)

        travel_to Time.current do
          magic_link.consume!
          expect(magic_link.used_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'returns true' do
        magic_link = create(:magic_link, :valid)
        expect(magic_link.consume!).to be true
      end
    end

    context 'when magic link is expired' do
      it 'returns false' do
        magic_link = create(:magic_link, :expired)
        expect(magic_link.consume!).to be false
      end

      it 'does not set used_at' do
        magic_link = create(:magic_link, :expired)
        magic_link.consume!
        expect(magic_link.used_at).to be_nil
      end
    end

    context 'when magic link is already used' do
      it 'returns false' do
        magic_link = create(:magic_link, :used)
        expect(magic_link.consume!).to be false
      end
    end
  end

  describe '.find_and_consume' do
    let(:user) { create(:user) }

    context 'with a valid token' do
      it 'returns the magic link' do
        magic_link = create(:magic_link, :valid, user: user)
        result = described_class.find_and_consume(magic_link.token)
        expect(result).to eq(magic_link)
      end

      it 'marks the magic link as used' do
        magic_link = create(:magic_link, :valid, user: user)
        described_class.find_and_consume(magic_link.token)
        expect(magic_link.reload.used?).to be true
      end
    end

    context 'with an expired token' do
      it 'returns nil' do
        magic_link = create(:magic_link, :expired, user: user)
        result = described_class.find_and_consume(magic_link.token)
        expect(result).to be_nil
      end
    end

    context 'with an already used token' do
      it 'returns nil' do
        magic_link = create(:magic_link, :used, user: user)
        result = described_class.find_and_consume(magic_link.token)
        expect(result).to be_nil
      end
    end

    context 'with a non-existent token' do
      it 'returns nil' do
        result = described_class.find_and_consume('non-existent-token')
        expect(result).to be_nil
      end
    end
  end

  describe 'User#generate_magic_link!' do
    let(:user) { create(:user) }

    it 'creates a new magic link for the user' do
      expect { user.generate_magic_link! }.to change { user.magic_links.count }.by(1)
    end

    it 'returns a valid magic link' do
      magic_link = user.generate_magic_link!
      expect(magic_link).to be_valid
      expect(magic_link).to be_persisted
      expect(magic_link.valid_for_use?).to be true
    end
  end
end