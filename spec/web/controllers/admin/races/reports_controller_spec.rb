# frozen_string_literal: true

require "rails_helper"

RSpec.describe Web::Controllers::Admin::Races::ReportsController, type: :request do
  let!(:admin) { create(:user, :admin, email_address: "admin@example.com", name: "Admin User") }
  let(:competition) { create(:competition) }
  let(:race_type) { create(:race_type_sprint) }
  let!(:race) { create(:race, :in_progress, competition: competition, race_type: race_type) }
  let!(:race_location) { create(:race_location, race: race) }
  let!(:athlete) { create(:athlete) }
  let!(:participation) { create(:race_participation, race: race, athlete: athlete, bib_number: 42) }

  before do
    post session_path, params: {
      email_address: "admin@example.com",
      password: "password123"
    }
  end

  describe "GET /admin/races/:race_id/reports" do
    context "when reports exist" do
      let!(:report1) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42) }
      let!(:report2) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42, status: "confirmed") }

      it "returns success" do
        get admin_race_reports_path(race)
        expect(response).to have_http_status(:success)
      end

      it "displays reports" do
        get admin_race_reports_path(race)
        expect(response.body).to include("42")
      end
    end

    context "when no reports exist" do
      it "returns success" do
        get admin_race_reports_path(race)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /admin/races/:race_id/reports/:id" do
    let!(:report) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42) }

    it "returns success" do
      get admin_race_report_path(race, report)
      expect(response).to have_http_status(:success)
    end

    it "displays report details" do
      get admin_race_report_path(race, report)
      expect(response.body).to include("42")
    end
  end

  describe "GET /admin/races/:race_id/reports/new" do
    it "returns success" do
      get new_admin_race_report_path(race)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /admin/races/:race_id/reports" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          report: {
            race_location_id: race_location.id,
            race_participation_id: participation.id,
            bib_number: 42,
            description: "Course cutting observed"
          }
        }
      end

      it "creates a new report" do
        expect {
          post admin_race_reports_path(race), params: valid_params
        }.to change(Report, :count).by(1)
      end

      it "redirects to the report show page" do
        post admin_race_reports_path(race), params: valid_params
        expect(response).to redirect_to(admin_race_report_path(race, Report.last))
      end

      it "sets success flash message" do
        post admin_race_reports_path(race), params: valid_params
        follow_redirect!
        expect(response.body).to include("created")
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          report: {
            race_location_id: nil,
            race_participation_id: nil,
            bib_number: nil
          }
        }
      end

      it "does not create a report" do
        expect {
          post admin_race_reports_path(race), params: invalid_params
        }.not_to change(Report, :count)
      end

      it "renders error" do
        post admin_race_reports_path(race), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /admin/races/:race_id/reports/:id/confirm" do
    context "when report is pending_review" do
      let!(:report) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42, status: "pending_review") }

      it "confirms the report" do
        post confirm_admin_race_report_path(race, report)
        expect(report.reload.status).to eq("confirmed")
      end

      it "redirects with success message" do
        post confirm_admin_race_report_path(race, report)
        expect(response).to redirect_to(admin_race_report_path(race, report))
        follow_redirect!
        expect(response.body).to include("confirmed")
      end
    end

    context "when report is already confirmed" do
      let!(:report) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42, status: "confirmed") }

      it "redirects with error message" do
        post confirm_admin_race_report_path(race, report)
        expect(response).to redirect_to(admin_race_report_path(race, report))
      end
    end
  end

  describe "POST /admin/races/:race_id/reports/:id/reject" do
    context "when report is pending_review" do
      let!(:report) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42, status: "pending_review") }

      it "rejects the report" do
        post reject_admin_race_report_path(race, report)
        expect(report.reload.status).to eq("rejected")
      end

      it "redirects with success message" do
        post reject_admin_race_report_path(race, report)
        expect(response).to redirect_to(admin_race_report_path(race, report))
        follow_redirect!
        expect(response.body).to include("rejected")
      end
    end

    context "when report is already rejected" do
      let!(:report) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42, status: "rejected") }

      it "redirects with error message" do
        post reject_admin_race_report_path(race, report)
        expect(response).to redirect_to(admin_race_report_path(race, report))
      end
    end
  end

  describe "POST /admin/races/:race_id/reports/:id/reopen" do
    context "when report is confirmed" do
      let!(:report) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42, status: "confirmed") }

      it "reopens the report" do
        post reopen_admin_race_report_path(race, report)
        expect(report.reload.status).to eq("pending_review")
      end

      it "redirects with success message" do
        post reopen_admin_race_report_path(race, report)
        expect(response).to redirect_to(admin_race_report_path(race, report))
        follow_redirect!
        expect(response.body).to include("reopened")
      end
    end

    context "when report is rejected" do
      let!(:report) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42, status: "rejected") }

      it "reopens the report" do
        post reopen_admin_race_report_path(race, report)
        expect(report.reload.status).to eq("pending_review")
      end
    end

    context "when report is already pending" do
      let!(:report) { create(:report, race: race, race_location: race_location, race_participation: participation, user: admin, bib_number: 42, status: "pending_review") }

      it "redirects with error message" do
        post reopen_admin_race_report_path(race, report)
        expect(response).to redirect_to(admin_race_report_path(race, report))
      end
    end
  end

  describe "authorization" do
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

      it "can access reports index" do
        get admin_race_reports_path(race)
        expect(response).to have_http_status(:success)
      end

      it "can create reports" do
        expect {
          post admin_race_reports_path(race), params: {
            report: {
              race_location_id: race_location.id,
              race_participation_id: participation.id,
              bib_number: 42
            }
          }
        }.to change(Report, :count).by(1)
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

      it "cannot access reports index" do
        get admin_race_reports_path(race)
        # Should be redirected or forbidden based on policy
        expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
      end
    end
  end
end
