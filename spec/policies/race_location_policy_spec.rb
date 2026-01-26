# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaceLocationPolicy, type: :policy do
  subject { described_class.new(user, race_location) }

  let(:race_location) { double('RaceLocation', from_template?: false, referee?: true) }

  describe 'for an admin user' do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:show_camera_stream) }
    it { is_expected.to permit_action(:manage_camera) }

    context 'when location is from template' do
      let(:race_location) { double('RaceLocation', from_template?: true, referee?: true) }

      it { is_expected.not_to permit_action(:destroy) }
    end
  end

  describe 'for a jury president' do
    let(:user) { create(:user, :jury_president) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.to permit_action(:show_camera_stream) }
    it { is_expected.to permit_action(:manage_camera) }
  end

  describe 'for a referee manager' do
    let(:user) { create(:user, :referee_manager) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:show_camera_stream) }
    it { is_expected.to permit_action(:manage_camera) }

    context 'when location is from template' do
      let(:race_location) { double('RaceLocation', from_template?: true, referee?: true) }

      it { is_expected.not_to permit_action(:destroy) }
    end
  end

  describe 'for an international referee' do
    let(:user) { create(:user, :international_referee) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:manage_camera) }

    context 'when location is designated for referees' do
      let(:race_location) { double('RaceLocation', from_template?: false, referee?: true) }

      it { is_expected.to permit_action(:show_camera_stream) }
    end

    context 'when location is not designated for referees' do
      let(:race_location) { double('RaceLocation', from_template?: false, referee?: false) }

      it { is_expected.not_to permit_action(:show_camera_stream) }
    end
  end

  describe 'for a national referee' do
    let(:user) { create(:user, :national_referee) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:manage_camera) }

    context 'when location is designated for referees' do
      let(:race_location) { double('RaceLocation', from_template?: false, referee?: true) }

      it { is_expected.to permit_action(:show_camera_stream) }
    end

    context 'when location is not designated for referees' do
      let(:race_location) { double('RaceLocation', from_template?: false, referee?: false) }

      it { is_expected.not_to permit_action(:show_camera_stream) }
    end
  end

  describe 'for a VAR operator' do
    let(:user) { create(:user, :var_operator) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.to permit_action(:show_camera_stream) }
    it { is_expected.not_to permit_action(:manage_camera) }
  end

  describe 'for a broadcast viewer' do
    let(:user) { create(:user, :broadcast_viewer) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:show_camera_stream) }
    it { is_expected.not_to permit_action(:manage_camera) }
  end

  describe 'for a user without a role' do
    let(:user) { create(:user, role: nil) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:show_camera_stream) }
    it { is_expected.not_to permit_action(:manage_camera) }
  end

  describe 'for nil user' do
    let(:user) { nil }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:show_camera_stream) }
  end

  describe RaceLocationPolicy::Scope do
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

      context 'when user is a broadcast viewer' do
        let(:user) { create(:user, :broadcast_viewer) }

        context 'when scope responds to with_camera' do
          let(:scope) { double('Scope', respond_to?: true) }

          it 'returns only locations with cameras' do
            allow(scope).to receive(:respond_to?).with(:with_camera).and_return(true)
            expect(scope).to receive(:with_camera)
            subject.resolve
          end
        end

        context 'when scope does not respond to with_camera' do
          let(:scope) { double('Scope') }

          it 'returns all locations' do
            allow(scope).to receive(:respond_to?).with(:with_camera).and_return(false)
            expect(scope).to receive(:all)
            subject.resolve
          end
        end
      end

      context 'when user is a referee' do
        let(:user) { create(:user, :national_referee) }

        it 'returns all locations' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is a VAR operator' do
        let(:user) { create(:user, :var_operator) }

        it 'returns all locations' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is a jury president' do
        let(:user) { create(:user, :jury_president) }

        it 'returns all locations' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is an admin' do
        let(:user) { create(:user, :admin) }

        it 'returns all locations' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end
    end
  end
end