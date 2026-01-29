# frozen_string_literal: true

require "rails_helper"

RSpec.describe RacePolicy do
  subject(:policy) { described_class.new(user, race) }

  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let(:race) { create(:race, competition: competition, race_type: race_type) }

  describe "permissions based on user role" do
    context "when user is an admin" do
      let(:user) { create(:user, admin: true) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.to permit_action(:new) }
      it { is_expected.to permit_action(:create) }
      it { is_expected.to permit_action(:edit) }
      it { is_expected.to permit_action(:update) }
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
      it { is_expected.to permit_action(:destroy) }
    end

    context "when user is a referee (national or international)" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:new) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:edit) }
      it { is_expected.not_to permit_action(:update) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is an international referee" do
      let(:referee_role) { create(:role, name: "international_referee") }
      let(:user) { create(:user, role: referee_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a referee manager" do
      let(:referee_manager_role) { create(:role, name: "referee_manager") }
      let(:user) { create(:user, role: referee_manager_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a jury president" do
      let(:jury_president_role) { create(:role, name: "jury_president") }
      let(:user) { create(:user, role: jury_president_role) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user is a broadcast viewer" do
      let(:broadcast_viewer_role) { create(:role, name: "broadcast_viewer") }
      let(:user) { create(:user, role: broadcast_viewer_role) }

      it { is_expected.not_to permit_action(:index) }
      it { is_expected.not_to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:destroy) }
    end

    context "when user has no role" do
      let(:user) { create(:user, role: nil) }

      it { is_expected.not_to permit_action(:index) }
      it { is_expected.not_to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:destroy) }
    end
  end

  describe "#update? business rules" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      context "when race is scheduled" do
        let(:race) { create(:race, :scheduled, competition: competition, race_type: race_type) }

        it "allows update" do
          expect(policy.update?).to be true
        end
      end

      context "when race is in_progress" do
        let(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }

        it "allows update" do
          expect(policy.update?).to be true
        end
      end

      context "when race is completed" do
        let(:race) do
          race_struct = create(:race, :completed, competition: competition, race_type: race_type)
          AppContainer["repos.race"].find(race_struct.id)
        end

        it "denies update (completed races cannot be edited)" do
          expect(policy.update?).to be false
        end
      end

      context "when race is cancelled" do
        let(:race) { create(:race, :cancelled, competition: competition, race_type: race_type) }

        it "allows update" do
          expect(policy.update?).to be true
        end
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      context "when race is completed" do
        let(:race) do
          race_record = create(:race, :completed, competition: competition, race_type: race_type)
          AppContainer["repos.race"].find(race_record.id)
        end

        it "denies update (completed races cannot be edited)" do
          expect(policy.update?).to be false
        end
      end

      context "when race is not completed" do
        let(:race) { create(:race, :scheduled, competition: competition, race_type: race_type) }

        it "allows update" do
          expect(policy.update?).to be true
        end
      end
    end

    context "when user is referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let(:user) { create(:user, role: referee_role) }

      context "even when race is scheduled" do
        let(:race) { create(:race, :scheduled, competition: competition, race_type: race_type) }

        it "denies update (referees are read-only)" do
          expect(policy.update?).to be false
        end
      end
    end
  end

  describe "#edit?" do
    let(:user) { create(:user, admin: true) }

    it "delegates to update?" do
      expect(policy.edit?).to eq(policy.update?)
    end

    context "when race is completed" do
      let(:race) do
        race_record = create(:race, :completed, competition: competition, race_type: race_type)
        AppContainer["repos.race"].find(race_record.id)
      end

      it "denies edit" do
        expect(policy.edit?).to be false
      end
    end
  end

  describe "#destroy?" do
    context "when user is admin" do
      let(:user) { create(:user, admin: true) }

      it "allows deletion at any time" do
        expect(policy.destroy?).to be true
      end

      context "even when race is completed" do
        let(:race) { create(:race, :completed, competition: competition, race_type: race_type) }

        it "allows deletion" do
          expect(policy.destroy?).to be true
        end
      end

      context "even when race has participants (future feature)" do
        let(:race) { create(:race, competition: competition, race_type: race_type) }

        it "allows deletion (as per requirements)" do
          expect(policy.destroy?).to be true
        end
      end
    end

    context "when user is VAR operator" do
      let(:var_operator_role) { create(:role, name: "var_operator") }
      let(:user) { create(:user, role: var_operator_role) }

      it "allows deletion" do
        expect(policy.destroy?).to be true
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
    let(:competition) { create(:competition) }
    let(:race_type) { create(:race_type_sprint) }
    let!(:race1) { create(:race, competition: competition, race_type: race_type) }
    let!(:race2) { create(:race, competition: competition, race_type: race_type) }

    describe "#resolve" do
      context "when user is admin" do
        let(:user) { create(:user, admin: true) }

        it "returns all races" do
          scope = described_class::Scope.new(user, Race.all).resolve
          expect(scope).to match_array([race1, race2])
        end
      end

      context "when user is VAR operator" do
        let(:var_operator_role) { create(:role, name: "var_operator") }
        let(:user) { create(:user, role: var_operator_role) }

        it "returns all races" do
          scope = described_class::Scope.new(user, Race.all).resolve
          expect(scope).to match_array([race1, race2])
        end
      end

      context "when user is referee" do
        let(:referee_role) { create(:role, name: "national_referee") }
        let(:user) { create(:user, role: referee_role) }

        it "returns all races (read-only access)" do
          scope = described_class::Scope.new(user, Race.all).resolve
          expect(scope).to match_array([race1, race2])
        end
      end

      context "when user is referee manager" do
        let(:referee_manager_role) { create(:role, name: "referee_manager") }
        let(:user) { create(:user, role: referee_manager_role) }

        it "returns all races" do
          scope = described_class::Scope.new(user, Race.all).resolve
          expect(scope).to match_array([race1, race2])
        end
      end

      context "when user is broadcast viewer" do
        let(:broadcast_viewer_role) { create(:role, name: "broadcast_viewer") }
        let(:user) { create(:user, role: broadcast_viewer_role) }

        it "returns no races" do
          scope = described_class::Scope.new(user, Race.all).resolve
          expect(scope).to be_empty
        end
      end

      context "when user has no role" do
        let(:user) { create(:user, role: nil) }

        it "returns no races" do
          scope = described_class::Scope.new(user, Race.all).resolve
          expect(scope).to be_empty
        end
      end
    end
  end

  describe "performance optimizations" do
    let(:user) { create(:user, admin: true) }

    it "memoizes role checks" do
      # First call should set instance variable
      policy.send(:admin?)
      expect(policy.instance_variable_get(:@admin)).to be true

      # Second call should return memoized value
      expect(policy.send(:admin?)).to be true
    end

    it "caches user_role_name" do
      # First call should fetch role name
      first_call = policy.send(:user_role_name)
      
      # Second call should use cached value
      second_call = policy.send(:user_role_name)
      expect(second_call).to eq(first_call)
    end
  end

  describe "edge cases" do
    context "when race record responds to completed? method" do
      let(:user) { create(:user, admin: true) }
      let(:race_struct) { Structs::Race.new(id: 1, status: "completed", competition_id: 1, race_type_id: 1, name: "Test", stage_type: "Final", stage_name: "Final", position: 0, created_at: Time.current, updated_at: Time.current) }

      it "uses the completed? method from struct" do
        policy = described_class.new(user, race_struct)
        expect(policy.update?).to be false
      end
    end

    context "when race record doesn't respond to completed?" do
      let(:user) { create(:user, admin: true) }
      let(:race_hash) { { id: 1, status: "scheduled" } }

      it "allows update (no completed? method to check)" do
        policy = described_class.new(user, race_hash)
        expect(policy.update?).to be true
      end
    end

    context "when user is nil" do
      let(:user) { nil }

      it "safely denies all actions" do
        expect(policy.index?).to be false
        expect(policy.show?).to be false
        expect(policy.create?).to be false
        expect(policy.update?).to be false
        expect(policy.destroy?).to be false
      end
    end
  end
end