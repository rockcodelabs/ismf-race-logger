# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncidentPolicy, type: :policy do
  subject { described_class.new(user, incident) }

  let(:incident) { double('Incident', unofficial?: true) }

  describe 'for an admin user' do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:officialize) }
    it { is_expected.not_to permit_action(:apply) }
    it { is_expected.not_to permit_action(:decline) }
  end

  describe 'for a jury president' do
    let(:user) { create(:user, :jury_president) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.to permit_action(:officialize) }
    it { is_expected.to permit_action(:apply) }
    it { is_expected.to permit_action(:apply_penalty) }
    it { is_expected.to permit_action(:decline) }
    it { is_expected.to permit_action(:reject) }
    it { is_expected.to permit_action(:no_action) }
  end

  describe 'for a referee manager' do
    let(:user) { create(:user, :referee_manager) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:officialize) }
    it { is_expected.not_to permit_action(:apply) }
    it { is_expected.not_to permit_action(:decline) }
  end

  describe 'for an international referee' do
    let(:user) { create(:user, :international_referee) }

    context 'with an unofficial incident' do
      let(:incident) { double('Incident', unofficial?: true) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
      it { is_expected.not_to permit_action(:officialize) }
      it { is_expected.not_to permit_action(:apply) }
      it { is_expected.not_to permit_action(:decline) }
    end

    context 'with an official incident' do
      let(:incident) { double('Incident', unofficial?: false) }

      it { is_expected.not_to permit_action(:update) }
    end
  end

  describe 'for a national referee' do
    let(:user) { create(:user, :national_referee) }

    context 'with an unofficial incident' do
      let(:incident) { double('Incident', unofficial?: true) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
      it { is_expected.not_to permit_action(:officialize) }
      it { is_expected.not_to permit_action(:apply) }
      it { is_expected.not_to permit_action(:decline) }
    end

    context 'with an official incident' do
      let(:incident) { double('Incident', unofficial?: false) }

      it { is_expected.not_to permit_action(:update) }
    end
  end

  describe 'for a VAR operator' do
    let(:user) { create(:user, :var_operator) }

    context 'with an unofficial incident' do
      let(:incident) { double('Incident', unofficial?: true) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
      it { is_expected.not_to permit_action(:officialize) }
      it { is_expected.not_to permit_action(:apply) }
      it { is_expected.not_to permit_action(:decline) }
    end

    context 'with an official incident' do
      let(:incident) { double('Incident', unofficial?: false) }

      it { is_expected.not_to permit_action(:update) }
    end
  end

  describe 'for a broadcast viewer' do
    let(:user) { create(:user, :broadcast_viewer) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:officialize) }
    it { is_expected.not_to permit_action(:apply) }
    it { is_expected.not_to permit_action(:decline) }
  end

  describe 'for a user without a role' do
    let(:user) { create(:user, role: nil) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:officialize) }
  end

  describe 'for nil user' do
    let(:user) { nil }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:officialize) }
  end

  describe IncidentPolicy::Scope do
    let(:scope) { double('Scope') }

    subject { described_class.new(user, scope) }

    describe '#resolve' do
      context 'when user is nil' do
        let(:user) { nil }

        it 'returns none' do
          expect(scope).to receive(:none)
          subject.resolve
        end
      end

      context 'when user is jury president' do
        let(:user) { create(:user, :jury_president) }

        it 'returns all incidents' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is referee manager' do
        let(:user) { create(:user, :referee_manager) }

        it 'returns all incidents' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is international referee' do
        let(:user) { create(:user, :international_referee) }

        it 'returns all incidents' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is VAR operator' do
        let(:user) { create(:user, :var_operator) }

        it 'returns all incidents' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is broadcast viewer' do
        let(:user) { create(:user, :broadcast_viewer) }

        it 'returns no incidents' do
          expect(scope).to receive(:none)
          subject.resolve
        end
      end
    end
  end
end
