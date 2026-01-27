# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:record) { double('Record') }

  describe 'default permissions' do
    let(:user) { create(:user) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:new) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:destroy) }
  end

  describe 'helper methods' do
    describe '#admin?' do
      context 'when user is admin' do
        let(:user) { create(:user, :admin) }

        it 'returns true' do
          expect(subject.send(:admin?)).to be true
        end
      end

      context 'when user is not admin' do
        let(:user) { create(:user, admin: false) }

        it 'returns false' do
          expect(subject.send(:admin?)).to be false
        end
      end

      context 'when user is nil' do
        let(:user) { nil }

        it 'returns false' do
          expect(subject.send(:admin?)).to be_falsey
        end
      end
    end

    describe '#referee?' do
      context 'when user is a national referee' do
        let(:user) { create(:user, :national_referee) }

        it 'returns true' do
          expect(subject.send(:referee?)).to be true
        end
      end

      context 'when user is an international referee' do
        let(:user) { create(:user, :international_referee) }

        it 'returns true' do
          expect(subject.send(:referee?)).to be true
        end
      end

      context 'when user is not a referee' do
        let(:user) { create(:user, :var_operator) }

        it 'returns false' do
          expect(subject.send(:referee?)).to be false
        end
      end
    end

    describe '#var_operator?' do
      context 'when user is a VAR operator' do
        let(:user) { create(:user, :var_operator) }

        it 'returns true' do
          expect(subject.send(:var_operator?)).to be true
        end
      end

      context 'when user is not a VAR operator' do
        let(:user) { create(:user, :national_referee) }

        it 'returns false' do
          expect(subject.send(:var_operator?)).to be false
        end
      end
    end

    describe '#jury_president?' do
      context 'when user is a jury president' do
        let(:user) { create(:user, :jury_president) }

        it 'returns true' do
          expect(subject.send(:jury_president?)).to be true
        end
      end

      context 'when user is not a jury president' do
        let(:user) { create(:user, :var_operator) }

        it 'returns false' do
          expect(subject.send(:jury_president?)).to be false
        end
      end
    end

    describe '#referee_manager?' do
      context 'when user is a referee manager' do
        let(:user) { create(:user, :referee_manager) }

        it 'returns true' do
          expect(subject.send(:referee_manager?)).to be true
        end
      end

      context 'when user is not a referee manager' do
        let(:user) { create(:user, :var_operator) }

        it 'returns false' do
          expect(subject.send(:referee_manager?)).to be false
        end
      end
    end

    describe '#broadcast_viewer?' do
      context 'when user is a broadcast viewer' do
        let(:user) { create(:user, :broadcast_viewer) }

        it 'returns true' do
          expect(subject.send(:broadcast_viewer?)).to be true
        end
      end

      context 'when user is not a broadcast viewer' do
        let(:user) { create(:user, :var_operator) }

        it 'returns false' do
          expect(subject.send(:broadcast_viewer?)).to be false
        end
      end
    end

    describe '#can_manage?' do
      context 'when user is admin' do
        let(:user) { create(:user, :admin) }

        it 'returns true' do
          expect(subject.send(:can_manage?)).to be true
        end
      end

      context 'when user is jury president' do
        let(:user) { create(:user, :jury_president) }

        it 'returns true' do
          expect(subject.send(:can_manage?)).to be true
        end
      end

      context 'when user is referee manager' do
        let(:user) { create(:user, :referee_manager) }

        it 'returns true' do
          expect(subject.send(:can_manage?)).to be true
        end
      end

      context 'when user is a regular referee' do
        let(:user) { create(:user, :national_referee) }

        it 'returns false' do
          expect(subject.send(:can_manage?)).to be false
        end
      end

      context 'when user is a VAR operator' do
        let(:user) { create(:user, :var_operator) }

        it 'returns false' do
          expect(subject.send(:can_manage?)).to be false
        end
      end
    end
  end

  describe ApplicationPolicy::Scope do
    let(:user) { create(:user) }
    let(:scope) { double('Scope') }

    subject { described_class.new(user, scope) }

    describe '#resolve' do
      it 'raises NotImplementedError' do
        expect { subject.resolve }.to raise_error(NotImplementedError)
      end
    end

    describe 'helper methods in scope' do
      it 'has access to admin? helper' do
        expect(subject.send(:admin?)).to be false
      end

      it 'has access to can_manage? helper' do
        expect(subject.send(:can_manage?)).to be false
      end

      it 'has access to referee? helper' do
        expect(subject.send(:referee?)).to be false
      end

      it 'has access to var_operator? helper' do
        expect(subject.send(:var_operator?)).to be false
      end
    end
  end
end
