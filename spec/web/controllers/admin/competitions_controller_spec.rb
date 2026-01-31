# frozen_string_literal: true

require "rails_helper"

RSpec.describe Web::Controllers::Admin::CompetitionsController, type: :request do
  let!(:admin) { create(:user, :admin, email_address: "admin@example.com", name: "Admin User") }

  before do
    post session_path, params: {
      email_address: "admin@example.com",
      password: "password123"
    }
  end

  describe "GET /admin/competitions" do
    let!(:competition1) { create(:competition, :verbier) }
    let!(:competition2) { create(:competition, :madonna) }
    let!(:competition3) { create(:competition, :andorra) }

    it "returns success" do
      get admin_competitions_path
      expect(response).to have_http_status(:success)
    end

    it "displays all competitions" do
      get admin_competitions_path
      # View uses display_name which is "#{city} #{year}", not the full name attribute
      expect(response.body).to include("Verbier 2024")
      expect(response.body).to include("Madonna di Campiglio 2024")
      expect(response.body).to include("Ordino 2024")
    end

    it "displays city names" do
      get admin_competitions_path
      expect(response.body).to include("Verbier")
      expect(response.body).to include("Madonna di Campiglio")
      expect(response.body).to include("Ordino")
    end

    it "displays country information" do
      get admin_competitions_path
      # View uses country_name which shows full country name, not alpha-3 code
      expect(response.body).to include("Switzerland")
      expect(response.body).to include("Italy")
      expect(response.body).to include("Andorra")
    end

    context "when no competitions exist" do
      before do
        Competition.destroy_all
      end

      it "displays empty state message" do
        get admin_competitions_path
        expect(response.body).to include("No competitions yet")
      end
    end
  end

  describe "GET /admin/competitions/new" do
    it "returns success" do
      get new_admin_competition_path
      expect(response).to have_http_status(:success)
    end

    it "renders the competition form" do
      get new_admin_competition_path
      expect(response.body).to include("New Competition")
      expect(response.body).to include("Name")
      expect(response.body).to include("City")
      expect(response.body).to include("Country")
      expect(response.body).to include("Start Date")
      expect(response.body).to include("End Date")
    end
  end

  describe "POST /admin/competitions" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          competition: {
            name: "World Cup Test 2024",
            city: "Test City",
            place: "Test Place",
            country: "CHE",
            description: "Test description",
            start_date: Date.current + 30.days,
            end_date: Date.current + 32.days,
            webpage_url: "https://example.com"
          }
        }
      end

      it "creates a new competition" do
        expect {
          post admin_competitions_path, params: valid_params
        }.to change(Competition, :count).by(1)
      end

      it "redirects to competition show page" do
        post admin_competitions_path, params: valid_params
        competition = Competition.last
        expect(response).to redirect_to(admin_competition_path(competition))
      end

      it "sets success flash message" do
        post admin_competitions_path, params: valid_params
        follow_redirect!
        expect(response.body).to include("was successfully created")
      end

      it "persists competition with correct attributes" do
        post admin_competitions_path, params: valid_params

        competition = Competition.last
        expect(competition.name).to eq("World Cup Test 2024")
        expect(competition.city).to eq("Test City")
        expect(competition.country).to eq("CHE")
      end
    end

    context "with invalid parameters (blank name)" do
      let(:invalid_params) do
        {
          competition: {
            name: "",
            city: "Test City",
            place: "Test Place",
            country: "CHE",
            description: "Test",
            start_date: Date.current + 30.days,
            end_date: Date.current + 32.days,
            webpage_url: "https://example.com"
          }
        }
      end

      it "does not create a competition" do
        expect {
          post admin_competitions_path, params: invalid_params
        }.not_to change(Competition, :count)
      end

      it "renders the new template with errors" do
        post admin_competitions_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("New Competition")
      end

      it "displays validation errors" do
        post admin_competitions_path, params: invalid_params
        expect(response.body).to include("must be filled")
      end
    end

    context "with invalid country code" do
      let(:invalid_params) do
        {
          competition: {
            name: "Test Competition",
            city: "Test City",
            place: "Test Place",
            country: "INVALID",
            description: "Test",
            start_date: Date.current + 30.days,
            end_date: Date.current + 32.days,
            webpage_url: "https://example.com"
          }
        }
      end

      it "does not create a competition" do
        expect {
          post admin_competitions_path, params: invalid_params
        }.not_to change(Competition, :count)
      end

      it "displays validation error for country" do
        post admin_competitions_path, params: invalid_params
        expect(response.body).to include("Country")
      end
    end

    context "with invalid date range (end before start)" do
      let(:invalid_params) do
        {
          competition: {
            name: "Test Competition",
            city: "Test City",
            place: "Test Place",
            country: "CHE",
            description: "Test",
            start_date: Date.current + 32.days,
            end_date: Date.current + 30.days,
            webpage_url: "https://example.com"
          }
        }
      end

      it "does not create a competition" do
        expect {
          post admin_competitions_path, params: invalid_params
        }.not_to change(Competition, :count)
      end

      it "displays validation error for dates" do
        post admin_competitions_path, params: invalid_params
        expect(response.body).to include("end_date")
      end
    end

    context "with invalid webpage URL" do
      let(:invalid_params) do
        {
          competition: {
            name: "Test Competition",
            city: "Test City",
            place: "Test Place",
            country: "CHE",
            description: "Test",
            start_date: Date.current + 30.days,
            end_date: Date.current + 32.days,
            webpage_url: "not-a-url"
          }
        }
      end

      it "does not create a competition" do
        expect {
          post admin_competitions_path, params: invalid_params
        }.not_to change(Competition, :count)
      end

      it "displays validation error for webpage_url" do
        post admin_competitions_path, params: invalid_params
        expect(response.body).to include("webpage_url")
      end
    end
  end

  describe "GET /admin/competitions/:id" do
    let!(:competition) { create(:competition, :verbier) }

    it "returns success" do
      get admin_competition_path(competition)
      expect(response).to have_http_status(:success)
    end

    it "displays competition details" do
      get admin_competition_path(competition)
      # View uses display_name which is "#{city} #{year}"
      expect(response.body).to include("Verbier 2024")
      expect(response.body).to include("Verbier")
      expect(response.body).to include("Swiss Alps")
      # View uses country_name which shows full country name
      expect(response.body).to include("Switzerland")
    end

    it "displays date range" do
      get admin_competition_path(competition)
      expect(response.body).to include(competition.start_date.strftime("%b %d"))
      expect(response.body).to include(competition.end_date.strftime("%b %d, %Y"))
    end

    it "displays description" do
      get admin_competition_path(competition)
      # Description is set in factory, check if it's present
      expect(response.body).to include(competition.description)
    end

    it "displays webpage URL" do
      get admin_competition_path(competition)
      expect(response.body).to include(competition.webpage_url)
    end

    context "when competition does not exist" do
      it "returns 404 or redirects" do
        get admin_competition_path(id: 999999)
        # Rails may return 404 or redirect depending on configuration
        expect(response.status).to be_in([302, 404])
      end
    end
  end

  describe "GET /admin/competitions/:id/edit" do
    let!(:competition) { create(:competition, :verbier) }

    it "returns success" do
      get edit_admin_competition_path(competition)
      expect(response).to have_http_status(:success)
    end

    it "renders the edit form" do
      get edit_admin_competition_path(competition)
      expect(response.body).to include("Edit Competition")
      expect(response.body).to include("World Cup Verbier 2024")
      expect(response.body).to include("Verbier")
    end

    it "pre-fills form with competition data" do
      get edit_admin_competition_path(competition)
      expect(response.body).to include(competition.name)
      expect(response.body).to include(competition.city)
      expect(response.body).to include(competition.country)
    end
  end

  describe "PATCH /admin/competitions/:id" do
    let!(:competition) { create(:competition, :verbier) }

    context "with valid parameters" do
      let(:valid_params) do
        {
          competition: {
            name: "World Cup Verbier 2025",
            city: "Verbier Updated",
            place: "Swiss Alps Updated"
          }
        }
      end

      it "updates the competition" do
        patch admin_competition_path(competition), params: valid_params

        competition.reload
        expect(competition.name).to eq("World Cup Verbier 2025")
        expect(competition.city).to eq("Verbier Updated")
        expect(competition.place).to eq("Swiss Alps Updated")
      end

      it "redirects to competition show page" do
        patch admin_competition_path(competition), params: valid_params
        expect(response).to redirect_to(admin_competition_path(competition))
      end

      it "sets success flash message" do
        patch admin_competition_path(competition), params: valid_params
        follow_redirect!
        expect(response.body).to include("was successfully updated")
      end

      it "does not change unspecified fields" do
        original_country = competition.country
        patch admin_competition_path(competition), params: {
          competition: { name: "Updated Name Only" }
        }

        competition.reload
        expect(competition.name).to eq("Updated Name Only")
        expect(competition.country).to eq(original_country)
      end
    end

    context "with invalid parameters (blank name)" do
      let(:invalid_params) do
        {
          competition: {
            name: ""
          }
        }
      end

      it "does not update the competition" do
        original_name = competition.name
        patch admin_competition_path(competition), params: invalid_params

        competition.reload
        expect(competition.name).to eq(original_name)
      end

      it "renders the edit template with errors" do
        patch admin_competition_path(competition), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Edit Competition")
      end

      it "displays validation errors" do
        patch admin_competition_path(competition), params: invalid_params
        expect(response.body).to include("must be filled")
      end
    end

    context "with invalid country code" do
      let(:invalid_params) do
        {
          competition: {
            country: "INVALID"
          }
        }
      end

      it "does not update the competition" do
        original_country = competition.country
        patch admin_competition_path(competition), params: invalid_params

        competition.reload
        expect(competition.country).to eq(original_country)
      end
    end

    context "with invalid date range" do
      let(:invalid_params) do
        {
          competition: {
            start_date: Date.current + 32.days,
            end_date: Date.current + 30.days
          }
        }
      end

      it "does not update the competition" do
        original_start = competition.start_date
        patch admin_competition_path(competition), params: invalid_params

        competition.reload
        expect(competition.start_date).to eq(original_start)
      end
    end
  end

  describe "DELETE /admin/competitions/:id" do
    let!(:competition) { create(:competition, :verbier) }

    it "deletes the competition" do
      expect {
        delete admin_competition_path(competition)
      }.to change(Competition, :count).by(-1)
    end

    it "redirects to competitions index" do
      delete admin_competition_path(competition)
      expect(response).to redirect_to(admin_competitions_path)
    end

    it "sets success flash message" do
      delete admin_competition_path(competition)
      follow_redirect!
      expect(response.body).to include("was successfully deleted")
    end

    context "when competition has associated races" do
      before do
        create(:race, :individual, competition: competition)
      end

      it "does not delete the competition" do
        expect {
          delete admin_competition_path(competition)
        }.not_to change(Competition, :count)
      end

      it "redirects with an error message" do
        delete admin_competition_path(competition)
        expect(response).to redirect_to(admin_competitions_path)
        follow_redirect!
        expect(response.body).to include("Cannot delete competition with existing races")
      end
    end
  end

  describe "authorization" do
    context "when user is not authenticated" do
      before do
        delete session_path
      end

      it "redirects to sign in for index" do
        get admin_competitions_path
        expect(response).to redirect_to(new_session_path)
      end

      it "redirects to sign in for new" do
        get new_admin_competition_path
        expect(response).to redirect_to(new_session_path)
      end

      it "redirects to sign in for create" do
        post admin_competitions_path, params: {
          competition: { name: "Test" }
        }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when user is not an admin" do
      let!(:regular_user) { create(:user, email_address: "user@example.com", admin: false) }

      before do
        delete session_path
        post session_path, params: {
          email_address: "user@example.com",
          password: "password123"
        }
      end

      it "allows access to index" do
        get admin_competitions_path
        expect(response).to have_http_status(:success)
      end

      it "redirects with unauthorized message for new" do
        get new_admin_competition_path
        expect(response).to redirect_to(root_path)
      end

      it "redirects with unauthorized message for create" do
        post admin_competitions_path, params: {
          competition: { name: "Test" }
        }
        expect(response).to redirect_to(root_path)
      end
    end
  end

end