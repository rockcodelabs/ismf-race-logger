# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Races::RaceLocations CRUD", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:competition) { create(:competition) }
  let(:race_type) { RaceType.find_by!(name: "Individual") }
  let(:race) { create(:race, competition: competition, race_type: race_type) }

  before do
    sign_in admin_user
  end

  describe "GET /admin/races/:race_id/race_locations" do
    context "when race has no locations" do
      it "displays empty state" do
        get admin_race_race_locations_path(race)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("No locations")
        expect(response.body).to include("Get started by creating a location")
      end

      it "shows zero counts in stats cards" do
        get admin_race_race_locations_path(race)

        expect(response.body).to include("Total Locations")
        expect(response.body).to match(/Total Locations.*?0/m)
      end
    end

    context "when race has locations" do
      let!(:location1) do
        create(:race_location,
               race: race,
               name: "Start",
               display_order: 0,
               is_standard: true,
               color_code: nil)
      end

      let!(:location2) do
        create(:race_location,
               race: race,
               name: "Top 1",
               display_order: 10,
               is_standard: true,
               color_code: "green")
      end

      let!(:location3) do
        create(:race_location,
               race: race,
               name: "Camera Gate 3",
               display_order: 20,
               is_standard: false,
               color_code: "red")
      end

      it "displays all locations" do
        get admin_race_race_locations_path(race)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Start")
        expect(response.body).to include("Top 1")
        expect(response.body).to include("Camera Gate 3")
      end

      it "shows correct counts in stats cards" do
        get admin_race_race_locations_path(race)

        # Parse the response to check stats
        expect(response.body).to match(/Total Locations.*?3/m)
        expect(response.body).to match(/Standard Locations.*?2/m)
        expect(response.body).to match(/Custom Locations.*?1/m)
      end

      it "displays locations in display_order" do
        get admin_race_race_locations_path(race)

        # Check that Start (order 0) appears before Top 1 (order 10)
        start_pos = response.body.index("Start")
        top_pos = response.body.index("Top 1")
        camera_pos = response.body.index("Camera Gate 3")

        expect(start_pos).to be < top_pos
        expect(top_pos).to be < camera_pos
      end

      it "shows race context banner" do
        get admin_race_race_locations_path(race)

        expect(response.body).to include(race.name)
        expect(response.body).to include(race_type.name)
      end

      it "includes breadcrumb navigation" do
        get admin_race_race_locations_path(race)

        expect(response.body).to include("Dashboard")
        expect(response.body).to include(competition.name)
        expect(response.body).to include("Races")
        expect(response.body).to include(race.name)
      end
    end
  end

  describe "GET /admin/races/:race_id/race_locations/new" do
    it "renders new location form" do
      get new_admin_race_race_location_path(race)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Add New Location")
      expect(response.body).to include("Location Name")
      expect(response.body).to include("Course Segment")
      expect(response.body).to include("Display Order")
    end

    it "includes all course segment options" do
      get new_admin_race_race_location_path(race)

      expect(response.body).to include("Start Area")
      expect(response.body).to include("Uphill 1")
      expect(response.body).to include("Descent")
      expect(response.body).to include("Finish Area")
    end

    it "includes all segment position options" do
      get new_admin_race_race_location_path(race)

      expect(response.body).to include("Start")
      expect(response.body).to include("Middle")
      expect(response.body).to include("Top")
      expect(response.body).to include("Bottom")
    end

    it "includes color code options" do
      get new_admin_race_race_location_path(race)

      expect(response.body).to include("Green (Uphill)")
      expect(response.body).to include("Red (Descent)")
      expect(response.body).to include("Yellow (Footpart)")
    end

    it "shows race context banner" do
      get new_admin_race_race_location_path(race)

      expect(response.body).to include(race.name)
      expect(response.body).to include(race_type.name)
    end
  end

  describe "POST /admin/races/:race_id/race_locations" do
    let(:valid_params) do
      {
        race_location: {
          name: "Top 2",
          course_segment: "uphill2",
          segment_position: "top",
          display_order: 30,
          color_code: "green",
          description: "Second top checkpoint"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new location" do
        expect do
          post admin_race_race_locations_path(race), params: valid_params
        end.to change(RaceLocation, :count).by(1)
      end

      it "redirects to locations index" do
        post admin_race_race_locations_path(race), params: valid_params

        expect(response).to redirect_to(admin_race_race_locations_path(race))
      end

      it "sets success notice" do
        post admin_race_race_locations_path(race), params: valid_params

        follow_redirect!
        expect(response.body).to include("Location &#39;Top 2&#39; was successfully added")
      end

      it "creates location with correct attributes" do
        post admin_race_race_locations_path(race), params: valid_params

        location = RaceLocation.last
        expect(location.race_id).to eq(race.id)
        expect(location.name).to eq("Top 2")
        expect(location.course_segment).to eq("uphill2")
        expect(location.segment_position).to eq("top")
        expect(location.display_order).to eq(30)
        expect(location.color_code).to eq("green")
        expect(location.description).to eq("Second top checkpoint")
        expect(location.is_standard).to be false
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          race_location: {
            name: "",
            course_segment: "uphill1",
            segment_position: "middle"
          }
        }
      end

      it "does not create a location" do
        expect do
          post admin_race_race_locations_path(race), params: invalid_params
        end.not_to change(RaceLocation, :count)
      end

      it "renders new template with errors" do
        post admin_race_race_locations_path(race), params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Add New Location")
      end

      it "displays error message" do
        post admin_race_race_locations_path(race), params: invalid_params

        expect(response.body).to include("error")
      end
    end

    context "with missing course_segment" do
      let(:invalid_params) do
        {
          race_location: {
            name: "Test Location",
            segment_position: "middle"
          }
        }
      end

      it "does not create a location" do
        expect do
          post admin_race_race_locations_path(race), params: invalid_params
        end.not_to change(RaceLocation, :count)
      end

      it "shows error message" do
        post admin_race_race_locations_path(race), params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/races/:race_id/race_locations/:id/edit" do
    let(:location) do
      create(:race_location,
             race: race,
             name: "Top 1",
             course_segment: "uphill1",
             segment_position: "top",
             display_order: 10,
             color_code: "green",
             is_standard: true)
    end

    it "renders edit form" do
      get edit_admin_race_race_location_path(race, location)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit Location")
      expect(response.body).to include("Top 1")
    end

    it "pre-fills form with location data" do
      get edit_admin_race_race_location_path(race, location)

      expect(response.body).to include('value="Top 1"')
      expect(response.body).to include('value="10"')
      expect(response.body).to include("uphill1")
      expect(response.body).to include("top")
    end

    it "shows location type badge" do
      get edit_admin_race_race_location_path(race, location)

      expect(response.body).to include("Standard Location")
    end

    it "shows danger zone for deletion" do
      get edit_admin_race_race_location_path(race, location)

      expect(response.body).to include("Danger Zone")
      expect(response.body).to include("Delete Location")
    end

    it "shows race context banner" do
      get edit_admin_race_race_location_path(race, location)

      expect(response.body).to include(race.name)
      expect(response.body).to include(race_type.name)
    end
  end

  describe "PATCH /admin/races/:race_id/race_locations/:id" do
    let(:location) do
      create(:race_location,
             race: race,
             name: "Top 1",
             course_segment: "uphill1",
             segment_position: "top",
             display_order: 10,
             color_code: "green")
    end

    let(:update_params) do
      {
        race_location: {
          name: "Top 1 Updated",
          course_segment: "uphill2",
          segment_position: "middle",
          display_order: 15,
          color_code: "red",
          description: "Updated description"
        }
      }
    end

    context "with valid parameters" do
      it "updates the location" do
        patch admin_race_race_location_path(race, location), params: update_params

        location.reload
        expect(location.name).to eq("Top 1 Updated")
        expect(location.course_segment).to eq("uphill2")
        expect(location.segment_position).to eq("middle")
        expect(location.display_order).to eq(15)
        expect(location.color_code).to eq("red")
        expect(location.description).to eq("Updated description")
      end

      it "redirects to locations index" do
        patch admin_race_race_location_path(race, location), params: update_params

        expect(response).to redirect_to(admin_race_race_locations_path(race))
      end

      it "sets success notice" do
        patch admin_race_race_location_path(race, location), params: update_params

        follow_redirect!
        expect(response.body).to include("was successfully updated")
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          race_location: {
            name: ""
          }
        }
      end

      it "does not update the location" do
        original_name = location.name
        patch admin_race_race_location_path(race, location), params: invalid_params

        location.reload
        expect(location.name).to eq(original_name)
      end

      it "renders edit template" do
        patch admin_race_race_location_path(race, location), params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Edit Location")
      end
    end
  end

  describe "DELETE /admin/races/:race_id/race_locations/:id" do
    let!(:location) do
      create(:race_location,
             race: race,
             name: "Camera Gate 5",
             display_order: 50)
    end

    it "deletes the location" do
      expect do
        delete admin_race_race_location_path(race, location)
      end.to change(RaceLocation, :count).by(-1)
    end

    it "redirects to locations index" do
      delete admin_race_race_location_path(race, location)

      expect(response).to redirect_to(admin_race_race_locations_path(race))
    end

    it "sets success notice" do
      delete admin_race_race_location_path(race, location)

      follow_redirect!
      expect(response.body).to include("was successfully deleted")
    end

    it "removes location from database" do
      location_id = location.id
      delete admin_race_race_location_path(race, location)

      expect(RaceLocation.find_by(id: location_id)).to be_nil
    end
  end

  describe "authorization" do
    context "when user is not admin" do
      let(:regular_user) { create(:user) }

      before do
        sign_out
        sign_in regular_user
      end

      it "denies access to index" do
        get admin_race_race_locations_path(race)

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)
      end

      it "denies access to new" do
        get new_admin_race_race_location_path(race)

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)
      end

      it "denies access to create" do
        post admin_race_race_locations_path(race), params: {
          race_location: { name: "Test", course_segment: "uphill1", segment_position: "middle" }
        }

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not signed in" do
      before do
        sign_out
      end

      it "redirects to sign in" do
        get admin_race_race_locations_path(race)

        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end