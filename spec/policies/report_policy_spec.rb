# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportPolicy, type: :policy do
  subject { described_class.new(user, report) }

  let(:report_owner) { create(:user, :national_referee) }
  let(:report) { double('Report', user_id: report_owner.id, draft?: true, submitted?: false) }

  describe 'for an admin user' do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:attach_video) }
    it { is_expected.not_to permit_action(:submit) }
  end

  describe 'for a jury president' do
    let(:user) { create(:user, :jury_president) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:submit) }
  end

  describe 'for a referee manager' do
    let(:user) { create(:user, :referee_manager) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:submit) }
  end

  describe 'for a national referee' do
    context 'when the referee owns the report' do
      let(:user) { report_owner }

      context 'when report is draft' do
        let(:report) { double('Report', user_id: user.id, draft?: true, submitted?: false) }

        it { is_expected.to permit_action(:index) }
        it { is_expected.to permit_action(:show) }
        it { is_expected.to permit_action(:create) }
        it { is_expected.to permit_action(:update) }
        it { is_expected.to permit_action(:destroy) }
        it { is_expected.to permit_action(:submit) }
        it { is_expected.to permit_action(:attach_video) }
      end

      context 'when report is submitted' do
        let(:report) { double('Report', user_id: user.id, draft?: false, submitted?: true) }

        it { is_expected.to permit_action(:update) }
        it { is_expected.not_to permit_action(:destroy) }
        it { is_expected.not_to permit_action(:submit) }
      end

      context 'when report is finalized' do
        let(:report) { double('Report', user_id: user.id, draft?: false, submitted?: false) }

        it { is_expected.not_to permit_action(:update) }
        it { is_expected.not_to permit_action(:destroy) }
        it { is_expected.not_to permit_action(:submit) }
      end
    end

    context 'when the referee does not own the report' do
      let(:user) { create(:user, :national_referee) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.not_to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
      it { is_expected.not_to permit_action(:submit) }
      it { is_expected.not_to permit_action(:attach_video) }
    end
  end

  describe 'for an international referee' do
    context 'when the referee owns the report' do
      let(:user) { create(:user, :international_referee) }
      let(:report) { double('Report', user_id: user.id, draft?: true, submitted?: false) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:destroy) }
      it { is_expected.to permit_action(:submit) }
    end

    context 'when the referee does not own the report' do
      let(:user) { create(:user, :international_referee) }

      it { is_expected.not_to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
      it { is_expected.not_to permit_action(:submit) }
    end
  end

  describe 'for a VAR operator' do
    context 'when the operator owns the report' do
      let(:user) { create(:user, :var_operator) }
      let(:report) { double('Report', user_id: user.id, draft?: true, submitted?: false) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:destroy) }
      it { is_expected.to permit_action(:submit) }
      it { is_expected.to permit_action(:attach_video) }
    end

    context 'when the operator does not own the report' do
      let(:user) { create(:user, :var_operator) }

      it { is_expected.not_to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
      it { is_expected.not_to permit_action(:submit) }
      it { is_expected.not_to permit_action(:attach_video) }
    end
  end

  describe 'for a broadcast viewer' do
    let(:user) { create(:user, :broadcast_viewer) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:submit) }
  end

  describe 'for a user without a role' do
    let(:user) { create(:user, role: nil) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:submit) }
  end

  describe 'for nil user' do
    let(:user) { nil }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:submit) }
  end

  describe ReportPolicy::Scope do
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

        it 'returns all reports' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is referee manager' do
        let(:user) { create(:user, :referee_manager) }

        it 'returns all reports' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is national referee' do
        let(:user) { create(:user, :national_referee) }

        it 'returns all reports' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is international referee' do
        let(:user) { create(:user, :international_referee) }

        it 'returns all reports' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is VAR operator' do
        let(:user) { create(:user, :var_operator) }

        it 'returns all reports' do
          expect(scope).to receive(:all)
          subject.resolve
        end
      end

      context 'when user is broadcast viewer' do
        let(:user) { create(:user, :broadcast_viewer) }

        it 'returns no reports' do
          expect(scope).to receive(:none)
          subject.resolve
        end
      end

      context 'when user has no role' do
        let(:user) { create(:user, role: nil) }

        it 'returns no reports' do
          expect(scope).to receive(:none)
          subject.resolve
        end
      end
    end
  end
end