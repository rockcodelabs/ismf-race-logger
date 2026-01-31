# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportPolicy do
  subject(:policy) { described_class.new(user, report) }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, competition: competition, race_type: race_type) }
  let(:report) { create(:report, race: race) }

  describe "permissions based on user role" do
    context "when user is an admin" do
      let(:user) { create(:user, admin: true) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:new) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:edit) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:confirm) }
      it { is_expected.to permit_action(:reject) }
      it { is_expected.to permit_action(:reopen) }
      it { is_expected.to permit_action(:destroy) }
    end

    context "when user is a VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:new) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:edit) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:confirm) }
      it { is_expected.to permit_action(:reject) }
      it { is_expected.to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a national referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:new) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:edit) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:confirm) }
      it { is_expected.to permit_action(:reject) }
      it { is_expected.to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is an international referee" do
      let(:referee_role) { create(:role, name: "international_referee") }
      let(:user) { create(:user, role: referee_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:confirm) }
      it { is_expected.to permit_action(:reject) }
      it { is_expected.to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a jury president" do
      let(:jury_president_role) { create(:role, name: "jury_president") }
      let(:user) { create(:user, role: jury_president_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:confirm) }
      it { is_expected.to permit_action(:reject) }
      it { is_expected.to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a referee manager" do
      let(:referee_manager_role) { create(:role, name: "referee_manager") }
      let(:user) { create(:user, role: referee_manager_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:confirm) }
      it { is_expected.to permit_action(:reject) }
      it { is_expected.to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a broadcast viewer" do
      let(:broadcast_viewer_role) { create(:role, name: "broadcast_viewer") }
      let(:user) { create(:user, role: broadcast_viewer_role) }

      it { is_expected.not_to permit_action(:index) }
      it { is_expected.not_to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:confirm) }
      it { is_expected.not_to permit_action(:reject) }
      it { is_expected.not_to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user has no role" do
      let(:user) { create(:user, role: nil) }

      it { is_expected.not_to permit_action(:index) }
      it { is_expected.not_to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:confirm) }
      it { is_expected.not_to permit_action(:reject) }
      it { is_expected.not_to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end
  end

  describe "#confirm?" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows confirming reports" do
        expect(policy.confirm?).to be true
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "allows confirming reports" do
        expect(policy.confirm?).to be true
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it "allows confirming reports" do
        expect(policy.confirm?).to be true
      end
    end
  end

  describe "#reject?" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows rejecting reports" do
        expect(policy.reject?).to be true
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "allows rejecting reports" do
        expect(policy.reject?).to be true
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it "allows rejecting reports" do
        expect(policy.reject?).to be true
      end
    end
  end

  describe "#reopen?" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows reopening reports" do
        expect(policy.reopen?).to be true
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "allows reopening reports" do
        expect(policy.reopen?).to be true
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it "allows reopening reports" do
        expect(policy.reopen?).to be true
      end
    end
  end

  describe "#destroy?" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows deletion" do
        expect(policy.destroy?).to be true
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "denies deletion" do
        expect(policy.destroy?).to be false
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it "denies deletion" do
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "Scope" do
    let!(:report1) { create(:report, race: race) }
    let!(:report2) { create(:report, race: race) }

    describe "#resolve" do
      context "when user is admin" do
        let(:user) { create(:user, admin: true) }

        it "returns all reports" do
          scope = described_class::Scope.new(user, Report.all).resolve
          expect(scope).to include(report1, report2)
        end
      end

      context "when user is VAR operator" do
        let(:var_operator_role) { create(:role, name: "var_operator") }
        let(:user) { create(:user, role: var_operator_role) }

        it "returns all reports" do
          scope = described_class::Scope.new(user, Report.all).resolve
          expect(scope).to include(report1, report2)
        end
      end

      context "when user is referee" do
        let(:referee_role) { create(:role, name: "national_referee") }
        let(:user) { create(:user, role: referee_role) }

        it "returns all reports" do
          scope = described_class::Scope.new(user, Report.all).resolve
          expect(scope).to include(report1, report2)
        end
      end

      context "when user is broadcast viewer" do
        let(:broadcast_viewer_role) { create(:role, name: "broadcast_viewer") }
        let(:user) { create(:user, role: broadcast_viewer_role) }

        it "returns no reports" do
          scope = described_class::Scope.new(user, Report.all).resolve
          expect(scope).to be_empty
        end
      end

      context "when user has no role" do
        let(:user) { create(:user, role: nil) }

        it "returns no reports" do
          scope = described_class::Scope.new(user, Report.all).resolve
          expect(scope).to be_empty
        end
      end
    end
  end

  describe "edge cases" do
    context "when user is nil" do
      let(:user) { nil }

      it "safely denies all actions" do
        expect(policy.index?).to be false
        expect(policy.show?).to be false
        expect(policy.create?).to be false
        expect(policy.confirm?).to be false
        expect(policy.reject?).to be false
        expect(policy.reopen?).to be false
        expect(policy.destroy?).to be false
      end
    end
  end
end
