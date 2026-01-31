# frozen_string_literal: true

require "rails_helper"

RSpec.describe Web::Controllers::Admin::Races::IncidentsController, type: :request do
  let!(:admin) { create(:user, :admin, email_address: "admin@example.com", name: "Admin User") }
  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let!(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let!(:race_location) { create(:race_location, race: race) }
  let!(:athlete) { create(:athlete) }
  let!(:participation) { create(:race_participation, race: race, athlete: athlete, bib_number: 42) }
  let!(:penalty) { create(:penalty) }

  before do
    post session_path, params: {
      email_address: "admin@example.com",
      password: "password123"
    }
  end

  describe "GET /admin/races/:race_id/incidents" do
    context "when incidents exist" do
      let!(:incident1) { create(:incident, race: race, race_location: race_location) }
      let!(:incident2) { create(:incident, race: race, race_location: race_location, status: "approved") }

      it "returns success" do
        get admin_race_incidents_path(race)
        expect(response).to have_http_status(:success)
      end

      it "displays incidents" do
        get admin_race_incidents_path(race)
        expect(response.body).to include("Incident")
      end
    end

    context "when no incidents exist" do
      it "returns success" do
        get admin_race_incidents_path(race)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /admin/races/:race_id/incidents/:id" do
    let!(:incident) { create(:incident, race: race, race_location: race_location) }

    it "returns success" do
      get admin_race_incident_path(race, incident)
      expect(response).to have_http_status(:success)
    end

    it "displays incident details" do
      get admin_race_incident_path(race, incident)
      expect(response.body).to include("Pending")
    end
  end

  describe "GET /admin/races/:race_id/incidents/new" do
    context "when confirmed reports exist" do
      let!(:confirmed_report) do
        create(:report,
               race: race,
               race_location: race_location,
               race_participation: participation,
               user: admin,
               bib_number: 42,
               status: "confirmed",
               incident: nil)
      end

      it "returns success" do
        get new_admin_race_incident_path(race)
        expect(response).to have_http_status(:success)
      end
    end

    context "when no confirmed reports exist" do
      it "redirects with alert" do
        get new_admin_race_incident_path(race)
        expect(response).to redirect_to(admin_race_incidents_path(race))
      end
    end
  end

  describe "POST /admin/races/:race_id/incidents" do
    context "with valid parameters" do
      let!(:confirmed_report1) do
        create(:report,
               race: race,
               race_location: race_location,
               race_participation: participation,
               user: admin,
               bib_number: 42,
               status: "confirmed",
               incident: nil)
      end

      let!(:confirmed_report2) do
        create(:report,
               race: race,
               race_location: race_location,
               race_participation: participation,
               user: admin,
               bib_number: 42,
               status: "confirmed",
               incident: nil)
      end

      it "creates a new incident" do
        expect {
          post admin_race_incidents_path(race), params: {
            report_ids: [ confirmed_report1.id, confirmed_report2.id ],
            description: "Multiple reports of course cutting"
          }
        }.to change(Incident, :count).by(1)
      end

      it "links reports to the incident" do
        post admin_race_incidents_path(race), params: {
          report_ids: [ confirmed_report1.id ],
          description: "Course cutting"
        }

        expect(confirmed_report1.reload.incident_id).not_to be_nil
      end

      it "redirects to the incident show page" do
        post admin_race_incidents_path(race), params: {
          report_ids: [ confirmed_report1.id ],
          description: "Course cutting"
        }
        expect(response).to redirect_to(admin_race_incident_path(race, Incident.last))
      end

      it "sets success flash message" do
        post admin_race_incidents_path(race), params: {
          report_ids: [ confirmed_report1.id ],
          description: "Course cutting"
        }
        follow_redirect!
        expect(response.body).to include("created")
      end
    end

    context "with no report_ids" do
      it "does not create an incident" do
        expect {
          post admin_race_incidents_path(race), params: {
            report_ids: [],
            description: "Test"
          }
        }.not_to change(Incident, :count)
      end

      it "renders error" do
        post admin_race_incidents_path(race), params: {
          report_ids: [],
          description: "Test"
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /admin/races/:race_id/incidents/:id/decide" do
    context "when incident is pending" do
      let!(:incident) { create(:incident, race: race, race_location: race_location, status: "pending") }

      it "approves the incident" do
        post decide_admin_race_incident_path(race, incident), params: {
          status: "approved",
          description: "Violation confirmed"
        }
        expect(incident.reload.status).to eq("approved")
      end

      it "rejects the incident" do
        post decide_admin_race_incident_path(race, incident), params: {
          status: "rejected",
          description: "No violation found"
        }
        expect(incident.reload.status).to eq("rejected")
      end

      it "sets decided_by_user_id" do
        post decide_admin_race_incident_path(race, incident), params: {
          status: "approved"
        }
        expect(incident.reload.decided_by_user_id).to eq(admin.id)
      end

      it "sets decided_at" do
        post decide_admin_race_incident_path(race, incident), params: {
          status: "approved"
        }
        expect(incident.reload.decided_at).not_to be_nil
      end

      it "redirects with success message" do
        post decide_admin_race_incident_path(race, incident), params: {
          status: "approved"
        }
        expect(response).to redirect_to(admin_race_incident_path(race, incident))
        follow_redirect!
        expect(response.body).to include("approved")
      end

      it "can attach penalties when approving" do
        post decide_admin_race_incident_path(race, incident), params: {
          status: "approved",
          penalty_ids: [ penalty.id ]
        }

        expect(incident.reload.penalties).to include(penalty)
      end
    end

    context "when incident is already decided" do
      let!(:incident) { create(:incident, race: race, race_location: race_location, status: "approved", decided_by_user: admin, decided_at: Time.current) }

      it "redirects with error" do
        post decide_admin_race_incident_path(race, incident), params: {
          status: "rejected"
        }
        expect(response).to redirect_to(admin_race_incident_path(race, incident))
      end
    end
  end

  describe "POST /admin/races/:race_id/incidents/:id/attach_penalties" do
    let!(:incident) { create(:incident, race: race, race_location: race_location) }
    let!(:penalty2) { create(:penalty) }

    it "attaches penalties to the incident" do
      post attach_penalties_admin_race_incident_path(race, incident), params: {
        penalty_ids: [ penalty.id, penalty2.id ]
      }

      expect(incident.reload.penalties).to include(penalty, penalty2)
    end

    it "replaces existing penalties" do
      incident.penalties << penalty

      post attach_penalties_admin_race_incident_path(race, incident), params: {
        penalty_ids: [ penalty2.id ]
      }

      expect(incident.reload.penalties).to eq([ penalty2 ])
    end

    it "can remove all penalties" do
      incident.penalties << penalty

      post attach_penalties_admin_race_incident_path(race, incident), params: {
        penalty_ids: []
      }

      expect(incident.reload.penalties).to be_empty
    end

    it "redirects with success message" do
      post attach_penalties_admin_race_incident_path(race, incident), params: {
        penalty_ids: [ penalty.id ]
      }
      expect(response).to redirect_to(admin_race_incident_path(race, incident))
      follow_redirect!
      expect(response.body).to include("Penalties updated")
    end
  end

  describe "POST /admin/races/:race_id/incidents/:id/reopen" do
    context "when incident is approved" do
      let!(:incident) { create(:incident, race: race, race_location: race_location, status: "approved", decided_by_user: admin, decided_at: Time.current) }

      it "reopens the incident" do
        post reopen_admin_race_incident_path(race, incident)
        expect(incident.reload.status).to eq("pending")
      end

      it "clears decision data" do
        post reopen_admin_race_incident_path(race, incident)
        incident.reload
        expect(incident.decided_by_user_id).to be_nil
        expect(incident.decided_at).to be_nil
      end

      it "redirects with success message" do
        post reopen_admin_race_incident_path(race, incident)
        expect(response).to redirect_to(admin_race_incident_path(race, incident))
        follow_redirect!
        expect(response.body).to include("reopened")
      end
    end

    context "when incident is rejected" do
      let!(:incident) { create(:incident, race: race, race_location: race_location, status: "rejected", decided_by_user: admin, decided_at: Time.current) }

      it "reopens the incident" do
        post reopen_admin_race_incident_path(race, incident)
        expect(incident.reload.status).to eq("pending")
      end
    end

    context "when incident is already pending" do
      let!(:incident) { create(:incident, race: race, race_location: race_location, status: "pending") }

      it "redirects with error message" do
        post reopen_admin_race_incident_path(race, incident)
        expect(response).to redirect_to(admin_race_incident_path(race, incident))
      end
    end
  end

  describe "authorization" do
    context "when user is a VAR operator" do
      let(:var_role) { create(:role, name: "var_operator") }
      let!(:var_user) { create(:user, role: var_role, email_address: "var@example.com", name: "VAR Operator") }

      before do
        delete session_path
        post session_path, params: {
          email_address: "var@example.com",
          password: "password123"
        }
      end

      it "can access incidents index" do
        get admin_race_incidents_path(race)
        expect(response).to have_http_status(:success)
      end

      it "can decide incidents" do
        incident = create(:incident, race: race, race_location: race_location, status: "pending")

        post decide_admin_race_incident_path(race, incident), params: {
          status: "approved"
        }

        expect(incident.reload.status).to eq("approved")
      end
    end

    context "when user is a referee" do
      let(:referee_role) { create(:role, name: "national_referee") }
      let!(:referee) { create(:user, role: referee_role, email_address: "referee@example.com", name: "Referee User") }

      before do
        delete session_path
        post session_path, params: {
          email_address: "referee@example.com",
          password: "password123"
        }
      end

      it "can access incidents index (read-only)" do
        get admin_race_incidents_path(race)
        expect(response).to have_http_status(:success)
      end

      it "can view incident details" do
        incident = create(:incident, race: race, race_location: race_location)
        get admin_race_incident_path(race, incident)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is a broadcast viewer" do
      let(:viewer_role) { create(:role, name: "broadcast_viewer") }
      let!(:viewer) { create(:user, role: viewer_role, email_address: "viewer@example.com", name: "Viewer User") }

      before do
        delete session_path
        post session_path, params: {
          email_address: "viewer@example.com",
          password: "password123"
        }
      end

      it "cannot access incidents index" do
        get admin_race_incidents_path(race)
        # Should be redirected or forbidden based on policy
        expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
      end
    end
  end
end
