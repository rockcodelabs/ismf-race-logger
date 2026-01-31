# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports Turbo Streams", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:race) { create(:race, :in_progress) }
  let(:race_location) { create(:race_location, race: race) }
  let(:race_participation) { create(:race_participation, race: race, bib_number: 42) }

  before do
    sign_in(admin_user)
  end

  describe "POST /admin/races/:race_id/reports (Turbo Stream)" do
    let(:valid_params) do
      {
        report: {
          race_location_id: race_location.id,
          race_participation_id: race_participation.id,
          bib_number: race_participation.bib_number,
          client_uuid: SecureRandom.uuid
        }
      }
    end

    context "with Turbo Stream request" do
      it "returns success status" do
        post admin_race_reports_path(race),
             params: valid_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
      end

      it "broadcasts to all connected clients" do
        expect_any_instance_of(ReportBroadcaster).to receive(:created).with(
          an_instance_of(Structs::Report),
          race.id
        )

        post admin_race_reports_path(race),
             params: valid_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "does not render local Turbo Streams (relies on broadcast)" do
        post admin_race_reports_path(race),
             params: valid_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        # Should return 200 OK without body (head :ok)
        expect(response.body).to be_empty
      end

      it "creates the report in the database" do
        expect {
          post admin_race_reports_path(race),
               params: valid_params,
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(Report, :count).by(1)
      end

      it "sets correct report attributes" do
        post admin_race_reports_path(race),
             params: valid_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        report = Report.last
        expect(report.race_id).to eq(race.id)
        expect(report.race_location_id).to eq(race_location.id)
        expect(report.race_participation_id).to eq(race_participation.id)
        expect(report.bib_number).to eq(42)
        expect(report.status).to eq("pending_review")
        expect(report.user_id).to eq(admin_user.id)
      end

      context "with validation errors" do
        let(:invalid_params) do
          {
            report: {
              race_location_id: nil,
              race_participation_id: nil,
              bib_number: nil
            }
          }
        end

        it "returns unprocessable entity status" do
          post admin_race_reports_path(race),
               params: invalid_params,
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "renders error flash message" do
          post admin_race_reports_path(race),
               params: invalid_params,
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response.body).to include("turbo-stream")
          expect(response.body).to include("flash-messages")
        end

        it "does not broadcast on validation failure" do
          expect_any_instance_of(ReportBroadcaster).not_to receive(:created)

          post admin_race_reports_path(race),
               params: invalid_params,
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end

        it "does not create a report" do
          expect {
            post admin_race_reports_path(race),
                 params: invalid_params,
                 headers: { "Accept" => "text/vnd.turbo-stream.html" }
          }.not_to change(Report, :count)
        end
      end
    end

    context "with HTML request (desktop)" do
      it "redirects to the report show page" do
        post admin_race_reports_path(race), params: valid_params

        expect(response).to redirect_to(admin_race_report_path(race, Report.last))
      end

      it "still broadcasts to all connected clients" do
        expect_any_instance_of(ReportBroadcaster).to receive(:created).with(
          an_instance_of(Structs::Report),
          race.id
        )

        post admin_race_reports_path(race), params: valid_params
      end
    end
  end

  describe "POST /admin/races/:race_id/reports/:id/confirm (Turbo Stream)" do
    let!(:report) do
      create(:report, :pending_review,
             race: race,
             race_location: race_location,
             race_participation: race_participation,
             user: admin_user,
             bib_number: 42)
    end

    context "with Turbo Stream request" do
      it "returns success status" do
        post confirm_admin_race_report_path(race, report),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
      end

      it "broadcasts to all connected clients" do
        expect_any_instance_of(ReportBroadcaster).to receive(:confirmed).with(
          an_instance_of(Structs::Report),
          race.id
        )

        post confirm_admin_race_report_path(race, report),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "does not render local Turbo Streams (relies on broadcast)" do
        post confirm_admin_race_report_path(race, report),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to be_empty
      end

      it "updates the report status to confirmed" do
        post confirm_admin_race_report_path(race, report),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(report.reload.status).to eq("confirmed")
      end

      context "with invalid status transition" do
        let!(:confirmed_report) do
          create(:report, :confirmed, race: race, user: admin_user)
        end

        it "returns error flash message" do
          post confirm_admin_race_report_path(race, confirmed_report),
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response.body).to include("turbo-stream")
          expect(response.body).to include("flash-messages")
        end

        it "does not broadcast on failure" do
          expect_any_instance_of(ReportBroadcaster).not_to receive(:confirmed)

          post confirm_admin_race_report_path(race, confirmed_report),
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end
      end
    end

    context "with HTML request (desktop)" do
      it "redirects to the report show page" do
        post confirm_admin_race_report_path(race, report)

        expect(response).to redirect_to(admin_race_report_path(race, report))
      end

      it "still broadcasts to all connected clients" do
        expect_any_instance_of(ReportBroadcaster).to receive(:confirmed).with(
          an_instance_of(Structs::Report),
          race.id
        )

        post confirm_admin_race_report_path(race, report)
      end
    end
  end

  describe "POST /admin/races/:race_id/reports/:id/reject (Turbo Stream)" do
    let!(:report) do
      create(:report, :pending_review,
             race: race,
             race_location: race_location,
             race_participation: race_participation,
             user: admin_user,
             bib_number: 42)
    end

    context "with Turbo Stream request" do
      it "returns success status" do
        post reject_admin_race_report_path(race, report),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
      end

      it "broadcasts to all connected clients" do
        expect_any_instance_of(ReportBroadcaster).to receive(:rejected).with(
          an_instance_of(Structs::Report),
          race.id
        )

        post reject_admin_race_report_path(race, report),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      it "does not render local Turbo Streams (relies on broadcast)" do
        post reject_admin_race_report_path(race, report),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to be_empty
      end

      it "updates the report status to rejected" do
        post reject_admin_race_report_path(race, report),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(report.reload.status).to eq("rejected")
      end

      context "with invalid status transition" do
        let!(:rejected_report) do
          create(:report, :rejected, race: race, user: admin_user)
        end

        it "returns error flash message" do
          post reject_admin_race_report_path(race, rejected_report),
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response.body).to include("turbo-stream")
          expect(response.body).to include("flash-messages")
        end

        it "does not broadcast on failure" do
          expect_any_instance_of(ReportBroadcaster).not_to receive(:rejected)

          post reject_admin_race_report_path(race, rejected_report),
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end
      end
    end

    context "with HTML request (desktop)" do
      it "redirects to the report show page" do
        post reject_admin_race_report_path(race, report)

        expect(response).to redirect_to(admin_race_report_path(race, report))
      end

      it "still broadcasts to all connected clients" do
        expect_any_instance_of(ReportBroadcaster).to receive(:rejected).with(
          an_instance_of(Structs::Report),
          race.id
        )

        post reject_admin_race_report_path(race, report)
      end
    end
  end

  describe "POST /admin/races/:race_id/reports/:id/reopen (HTML only)" do
    let!(:report) do
      create(:report, :confirmed,
             race: race,
             race_location: race_location,
             race_participation: race_participation,
             user: admin_user,
             bib_number: 42)
    end

    it "redirects to the report show page" do
      post reopen_admin_race_report_path(race, report)

      expect(response).to redirect_to(admin_race_report_path(race, report))
    end

    it "broadcasts to all connected clients" do
      expect_any_instance_of(ReportBroadcaster).to receive(:reopened).with(
        an_instance_of(Structs::Report),
        race.id
      )

      post reopen_admin_race_report_path(race, report)
    end

    it "updates the report status to pending_review" do
      post reopen_admin_race_report_path(race, report)

      expect(report.reload.status).to eq("pending_review")
    end

    context "with already pending report" do
      let!(:pending_report) do
        create(:report, :pending_review, race: race, user: admin_user)
      end

      it "shows error message" do
        post reopen_admin_race_report_path(race, pending_report)

        follow_redirect!
        expect(response.body).to include("already pending")
      end

      it "does not broadcast on failure" do
        expect_any_instance_of(ReportBroadcaster).not_to receive(:reopened)

        post reopen_admin_race_report_path(race, pending_report)
      end
    end
  end

  describe "broadcasting integration" do
    let!(:report) do
      create(:report, :pending_review,
             race: race,
             race_location: race_location,
             race_participation: race_participation,
             user: admin_user,
             bib_number: 42)
    end

    it "broadcasts create from both HTML and Turbo Stream requests" do
      expect_any_instance_of(ReportBroadcaster).to receive(:created).twice

      # HTML request
      post admin_race_reports_path(race), params: {
        report: {
          race_location_id: race_location.id,
          race_participation_id: race_participation.id,
          bib_number: 99,
          client_uuid: SecureRandom.uuid
        }
      }

      # Turbo Stream request
      post admin_race_reports_path(race),
           params: {
             report: {
               race_location_id: race_location.id,
               race_participation_id: race_participation.id,
               bib_number: 100,
               client_uuid: SecureRandom.uuid
             }
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "broadcasts confirm from both HTML and Turbo Stream requests" do
      report2 = create(:report, :pending_review, race: race, user: admin_user)

      expect_any_instance_of(ReportBroadcaster).to receive(:confirmed).twice

      # HTML request
      post confirm_admin_race_report_path(race, report)

      # Turbo Stream request
      post confirm_admin_race_report_path(race, report2),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "broadcasts reject from both HTML and Turbo Stream requests" do
      report2 = create(:report, :pending_review, race: race, user: admin_user)

      expect_any_instance_of(ReportBroadcaster).to receive(:rejected).twice

      # HTML request
      post reject_admin_race_report_path(race, report)

      # Turbo Stream request
      post reject_admin_race_report_path(race, report2),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
  end

  describe "race isolation" do
    let(:other_race) { create(:race, :in_progress) }
    let!(:other_report) do
      create(:report, :pending_review,
             race: other_race,
             user: admin_user)
    end

    it "only broadcasts to the specific race stream" do
      expect_any_instance_of(ReportBroadcaster).to receive(:confirmed).with(
        an_instance_of(Structs::Report),
        race.id
      ).and_call_original

      expect_any_instance_of(ReportBroadcaster).not_to receive(:confirmed).with(
        anything,
        other_race.id
      )

      report = create(:report, :pending_review, race: race, user: admin_user)
      post confirm_admin_race_report_path(race, report),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
  end

  describe "authorization" do
    context "when not authenticated" do
      before { sign_out }

      it "redirects to sign in page" do
        post admin_race_reports_path(race),
             params: {
               report: {
                 race_location_id: race_location.id,
                 race_participation_id: race_participation.id,
                 bib_number: 42
               }
             },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to redirect_to(new_session_path)
      end

      it "does not broadcast when unauthorized" do
        expect_any_instance_of(ReportBroadcaster).not_to receive(:created)

        post admin_race_reports_path(race),
             params: {
               report: {
                 race_location_id: race_location.id,
                 race_participation_id: race_participation.id,
                 bib_number: 42
               }
             },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end
    end
  end
end