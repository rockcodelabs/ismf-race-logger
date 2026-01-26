# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaceTypePolicy, type: :policy do
  subject { described_class.new(user, race_type) }

  let(:race_type) { double('RaceType') }

  describe 'for an admin user' do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.to permit_action(:manage_templates) }
    it { is_expected.to permit_action(:add_location_template) }
    it { is_expected.to permit_action(:remove_location_template) }
  end

  describe 'for a jury president' do
    let(:user) { create(:user, :jury_president) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.to permit_action(:manage_templates) }
    it { is_expected.to permit_action(:add_location_template) }
    it { is_expected.to permit_action(:remove_location_template) }
  end

  describe 'for a referee manager' do
    let(:user) { create(:user, :referee_manager) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:manage_templates) }
    it { is_expected.to permit_action(:add_location_template) }
    it { is_expected.to permit_action(:remove_location_template) }
  end

  describe 'for an international referee' do
    let(:user) { create(:user, :international_referee) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:manage_templates) }
    it { is_expected.not_to permit_action(:add_location_template) }
    it { is_expected.not_to permit_action(:remove_location_template) }
  end

  describe 'for a national referee' do
    let(:user) { create(:user, :national_referee) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:manage_templates) }
    it { is_expected.not_to permit_action(:add_location_template) }
    it { is_expected.not_to permit_action(:remove_location_template) }
  end

  describe 'for a VAR operator' do
    let(:user) { create(:user, :var_operator) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:manage_templates) }
    it { is_expected.not_to permit_action(:add_location_template) }
    it { is_expected.not_to permit_action(:remove_location_template) }
  end

  describe 'for a broadcast viewer' do
    let(:user) { create(:user, :broadcast_viewer) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:manage_templates) }
    it { is_expected.not_to permit_action(:add_location_template) }
    it { is_expected.not_to permit_action(:remove_location_template) }
  end

  describe 'for a user without a role' do
    let(:user) { create(:user, role: nil) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:manage_templates) }
  end

  describe 'for nil user' do
    let(:user) { nil }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:manage_templates) }
  end

  describe RaceTypePolicy::Scope do
    let(:scope) { double('Scope') }

    subject { described_class.new(user, scope) }

    describe '#resolve' do
      context 'for any authenticated user' do
        let(:user) { create(:user) }

        it 'returns all race types' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'for a broadcast viewer' do
        let(:user) { create(:user, :broadcast_viewer) }

        it 'returns all race types' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'for a referee' do
        let(:user) { create(:user, :national_referee) }

        it 'returns all race types' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'for a VAR operator' do
        let(:user) { create(:user, :var_operator) }

        it 'returns all race types' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'for an admin' do
        let(:user) { create(:user, :admin) }

        it 'returns all race types' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end
    end
  end
end