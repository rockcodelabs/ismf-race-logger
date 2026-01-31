# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncidentPolicy do
  subject(:policy) { described_class.new(user, incident) }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, competition: competition, race_type: race_type) }
  let(:incident) { create(:incident, race: race) }

  describe "permissions based on user role" do
    context "when user is an admin" do
      let(:user) { create(:user, admin: true) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:new) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:edit) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:decide) }
      it { is_expected.to permit_action(:attach_penalties) }
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
      it { is_expected.to permit_action(:decide) }
      it { is_expected.to permit_action(:attach_penalties) }
      it { is_expected.to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a national referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:new) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:edit) }
      it { is_expected.not_to permit_action(:update) }
      it { is_expected.not_to permit_action(:decide) }
      it { is_expected.not_to permit_action(:attach_penalties) }
      it { is_expected.not_to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is an international referee" do
      let(:referee_role) { create(:role, name: "international_referee") }
      let(:user) { create(:user, role: referee_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:decide) }
      it { is_expected.not_to permit_action(:attach_penalties) }
      it { is_expected.not_to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a referee manager" do
      let(:referee_manager_role) { create(:role, name: "referee_manager") }
      let(:user) { create(:user, role: referee_manager_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:decide) }
      it { is_expected.not_to permit_action(:attach_penalties) }
      it { is_expected.not_to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a jury president" do
      let(:jury_president_role) { create(:role, name: "jury_president") }
      let(:user) { create(:user, role: jury_president_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:decide) }
      it { is_expected.not_to permit_action(:attach_penalties) }
      it { is_expected.not_to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a broadcast viewer" do
      let(:broadcast_viewer_role) { create(:role, name: "broadcast_viewer") }
      let(:user) { create(:user, role: broadcast_viewer_role) }

      it { is_expected.not_to permit_action(:index) }
      it { is_expected.not_to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:decide) }
      it { is_expected.not_to permit_action(:attach_penalties) }
      it { is_expected.not_to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user has no role" do
      let(:user) { create(:user, role: nil) }

      it { is_expected.not_to permit_action(:index) }
      it { is_expected.not_to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:decide) }
      it { is_expected.not_to permit_action(:attach_penalties) }
      it { is_expected.not_to permit_action(:reopen) }
      it { is_expected.not_to permit_action(:destroy) }
    end
  end

  describe "#create? (merge reports)" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows merging reports into incidents" do
        expect(policy.create?).to be true
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "allows merging reports into incidents" do
        expect(policy.create?).to be true
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it "denies merging reports into incidents" do
        expect(policy.create?).to be false
      end
    end
  end

  describe "#decide?" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows making decisions on incidents" do
        expect(policy.decide?).to be true
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "allows making decisions on incidents" do
        expect(policy.decide?).to be true
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it "denies making decisions on incidents" do
        expect(policy.decide?).to be false
      end
    end

    context "when user is jury president" do
      let(:jury_president_role) { create(:role, name: "jury_president") }
      let(:user) { create(:user, role: jury_president_role) }

      it "denies making decisions on incidents (can_manage? but not admin/VAR)" do
        expect(policy.decide?).to be false
      end
    end
  end

  describe "#attach_penalties?" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows attaching penalties to incidents" do
        expect(policy.attach_penalties?).to be true
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "allows attaching penalties to incidents" do
        expect(policy.attach_penalties?).to be true
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "international_referee") }
      let(:user) { create(:user, role: referee_role) }

      it "denies attaching penalties to incidents" do
        expect(policy.attach_penalties?).to be false
      end
    end
  end

  describe "#reopen?" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows reopening decided incidents" do
        expect(policy.reopen?).to be true
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "allows reopening decided incidents" do
        expect(policy.reopen?).to be true
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it "denies reopening incidents" do
        expect(policy.reopen?).to be false
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

      it "denies deletion (only admins can delete)" do
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
    let!(:incident1) { create(:incident, race: race) }
    let!(:incident2) { create(:incident, race: race) }

    describe "#resolve" do
      context "when user is admin" do
        let(:user) { create(:user, admin: true) }

        it "returns all incidents" do
          scope = described_class::Scope.new(user, Incident.all).resolve
          expect(scope).to include(incident1, incident2)
        end
      end

      context "when user is VAR operator" do
        let(:var_operator_role) { create(:role, name: "var_operator") }
        let(:user) { create(:user, role: var_operator_role) }

        it "returns all incidents" do
          scope = described_class::Scope.new(user, Incident.all).resolve
          expect(scope).to include(incident1, incident2)
        end
      end

      context "when user is referee" do
        let(:referee_role) { create(:role, name: "national_referee") }
        let(:user) { create(:user, role: referee_role) }

        it "returns all incidents (read-only access)" do
          scope = described_class::Scope.new(user, Incident.all).resolve
          expect(scope).to include(incident1, incident2)
        end
      end

      context "when user is broadcast viewer" do
        let(:broadcast_viewer_role) { create(:role, name: "broadcast_viewer") }
        let(:user) { create(:user, role: broadcast_viewer_role) }

        it "returns no incidents" do
          scope = described_class::Scope.new(user, Incident.all).resolve
          expect(scope).to be_empty
        end
      end

      context "when user has no role" do
        let(:user) { create(:user, role: nil) }

        it "returns no incidents" do
          scope = described_class::Scope.new(user, Incident.all).resolve
          expect(scope).to be_empty
        end
      end
    end
  end

  describe "performance optimizations" do
    let(:user) { create(:user, admin: true) }

    it "memoizes admin_or_var? check" do
      # First call should set instance variable
      policy.send(:admin_or_var?)
      expect(policy.instance_variable_get(:@admin_or_var)).to be true

      # Second call should return memoized value
      expect(policy.send(:admin_or_var?)).to be true
    end
  end

  describe "edge cases" do
    context "when user is nil" do
      let(:user) { nil }

      it "safely denies all actions" do
        expect(policy.index?).to be false
        expect(policy.show?).to be false
        expect(policy.create?).to be false
        expect(policy.decide?).to be false
        expect(policy.attach_penalties?).to be false
        expect(policy.reopen?).to be false
        expect(policy.destroy?).to be false
      end
    end

    context "when incident is nil" do
      let(:user) { create(:user, admin: true) }
      let(:incident) { nil }

      it "still evaluates permissions based on user role" do
        expect(policy.create?).to be true
        expect(policy.decide?).to be true
      end
    end
  end
end
