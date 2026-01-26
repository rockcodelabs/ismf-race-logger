# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:users).dependent(:nullify) }
  end

  describe 'validations' do
    subject { create(:role, :var_operator) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_inclusion_of(:name).in_array(Role::NAMES) }

    it 'rejects invalid role names' do
      role = build(:role, name: 'invalid_role')
      expect(role).not_to be_valid
      expect(role.errors[:name]).to include('is not included in the list')
    end
  end

  describe 'NAMES constant' do
    it 'includes all expected role names' do
      expected_roles = %w[
        var_operator
        national_referee
        international_referee
        jury_president
        referee_manager
        broadcast_viewer
      ]
      expect(Role::NAMES).to match_array(expected_roles)
    end

    it 'is frozen' do
      expect(Role::NAMES).to be_frozen
    end
  end

  describe 'scopes' do
    let!(:var_operator) { create(:role, :var_operator) }
    let!(:national_referee) { create(:role, :national_referee) }
    let!(:international_referee) { create(:role, :international_referee) }
    let!(:jury_president) { create(:role, :jury_president) }

    describe '.referee_roles' do
      it 'returns only referee roles' do
        expect(described_class.referee_roles).to contain_exactly(
          national_referee,
          international_referee
        )
      end
    end

    describe '.operator_roles' do
      it 'returns only var_operator roles' do
        expect(described_class.operator_roles).to contain_exactly(var_operator)
      end
    end
  end

  describe 'role check methods' do
    describe '#referee?' do
      it 'returns true for national_referee' do
        role = build(:role, :national_referee)
        expect(role.referee?).to be true
      end

      it 'returns true for international_referee' do
        role = build(:role, :international_referee)
        expect(role.referee?).to be true
      end

      it 'returns false for non-referee roles' do
        role = build(:role, :var_operator)
        expect(role.referee?).to be false
      end
    end

    describe '#operator?' do
      it 'returns true for var_operator' do
        role = build(:role, :var_operator)
        expect(role.operator?).to be true
      end

      it 'returns false for non-operator roles' do
        role = build(:role, :national_referee)
        expect(role.operator?).to be false
      end
    end

    describe '#jury?' do
      it 'returns true for jury_president' do
        role = build(:role, :jury_president)
        expect(role.jury?).to be true
      end

      it 'returns false for non-jury roles' do
        role = build(:role, :var_operator)
        expect(role.jury?).to be false
      end
    end

    describe '#manager?' do
      it 'returns true for referee_manager' do
        role = build(:role, :referee_manager)
        expect(role.manager?).to be true
      end

      it 'returns false for non-manager roles' do
        role = build(:role, :var_operator)
        expect(role.manager?).to be false
      end
    end

    describe '#viewer?' do
      it 'returns true for broadcast_viewer' do
        role = build(:role, :broadcast_viewer)
        expect(role.viewer?).to be true
      end

      it 'returns false for non-viewer roles' do
        role = build(:role, :var_operator)
        expect(role.viewer?).to be false
      end
    end
  end

  describe '.seed_all!' do
    it 'creates all roles from NAMES' do
      expect { described_class.seed_all! }.to change(described_class, :count).by(Role::NAMES.size)
    end

    it 'is idempotent' do
      described_class.seed_all!
      expect { described_class.seed_all! }.not_to change(described_class, :count)
    end

    it 'creates each role name' do
      described_class.seed_all!
      Role::NAMES.each do |name|
        expect(described_class.exists?(name: name)).to be true
      end
    end
  end
end