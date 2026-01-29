# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /admin/competitions/:competition_id/races", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }

  before do
    sign_in(admin_user)
  end

  context "with valid parameters" do
    let(:valid_params) do
      {
        race: {
          race_type_id: race_type.id,
          name: "Women's Sprint - Qualification",
          stage_type: "Qualification",
          heat_number: nil,
          scheduled_at: 2.hours.from_now
        }
      }
    end

    it "creates a new race" do
      expect {
        post admin_competition_races_path(competition), params: valid_params
      }.to change(Race, :count).by(1)
    end

    it "redirects to the races index" do
      post admin_competition_races_path(competition), params: valid_params

      expect(response).to redirect_to(admin_competition_races_path(competition))
    end

    it "sets a success flash message" do
      post admin_competition_races_path(competition), params: valid_params

      follow_redirect!
      expect(response.body).to include("successfully created")
    end

    it "sets the race attributes correctly" do
      post admin_competition_races_path(competition), params: valid_params

      race = Race.last
      expect(race.name).to eq("Women's Sprint - Qualification")
      expect(race.stage_type).to eq("Qualification")
      expect(race.heat_number).to be_nil
      expect(race.stage_name).to eq("Qualification")
      expect(race.competition_id).to eq(competition.id)
      expect(race.race_type_id).to eq(race_type.id)
      expect(race.status).to eq("scheduled")
    end

    it "auto-assigns position" do
      post admin_competition_races_path(competition), params: valid_params

      race = Race.last
      expect(race.position).to eq(0)
    end

    context "when races already exist for the same race type" do
      before do
        create(:race, competition: competition, race_type: race_type, position: 0)
        create(:race, competition: competition, race_type: race_type, position: 1)
      end

      it "assigns the next position" do
        post admin_competition_races_path(competition), params: valid_params

        race = Race.last
        expect(race.position).to eq(2)
      end
    end

    context "with heat number" do
      let(:valid_params_with_heat) do
        {
          race: {
            race_type_id: race_type.id,
            name: "Women's Sprint - Semifinal 1",
            stage_type: "Semifinal",
            heat_number: 1,
            scheduled_at: 3.hours.from_now
          }
        }
      end

      it "computes stage_name with heat number" do
        post admin_competition_races_path(competition), params: valid_params_with_heat

        race = Race.last
        expect(race.stage_name).to eq("Semifinal 1")
      end
    end

    context "without scheduled_at" do
      let(:params_without_schedule) do
        {
          race: {
            race_type_id: race_type.id,
            name: "Women's Sprint - Final",
            stage_type: "Final"
          }
        }
      end

      it "creates race without scheduled_at" do
        post admin_competition_races_path(competition), params: params_without_schedule

        race = Race.last
        expect(race.scheduled_at).to be_nil
      end
    end
  end

  context "with invalid parameters" do
    let(:invalid_params) do
      {
        race: {
          race_type_id: nil,
          name: "",
          stage_type: ""
        }
      }
    end

    it "does not create a race" do
      expect {
        post admin_competition_races_path(competition), params: invalid_params
      }.not_to change(Race, :count)
    end

    it "renders the new template with errors" do
      post admin_competition_races_path(competition), params: invalid_params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("fix the following errors")
    end

    it "repopulates the form with submitted values" do
      post admin_competition_races_path(competition), params: invalid_params

      expect(response.body).to include("race_type_id")
    end
  end

  context "when not authenticated" do
    before { sign_out }

    it "redirects to sign in page" do
      post admin_competition_races_path(competition), params: {
        race: { name: "Test" }
      }

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "when authenticated as non-admin" do
    let(:referee_role) { create(:role, name: "national_referee") }
    let(:referee_user) { create(:user, role: referee_role) }

    before do
      sign_out
      sign_in(referee_user)
    end

    it "redirects with authorization error" do
      post admin_competition_races_path(competition), params: {
        race: {
          race_type_id: race_type.id,
          name: "Test Race",
          stage_type: "Final"
        }
      }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("must be an administrator")
    end
  end
end