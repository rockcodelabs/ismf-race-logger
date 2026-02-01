# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Reports::Videos" do
  let(:user) { create(:user, :admin) }
  let(:race) { create(:race, :in_progress) }
  let(:race_location) { create(:race_location, race: race) }
  let(:race_participation) { create(:race_participation, race: race) }
  let(:report) { create(:report, race: race, user: user, race_location: race_location, race_participation: race_participation) }

  before do
    sign_in user
  end

  describe "POST /admin/races/:race_id/reports/:report_id/videos" do
    let(:path) { admin_race_report_videos_path(race, report) }

    context "with valid video blobs" do
      let(:blob_1) { create_video_blob("video1.mp4", size: 20.megabytes) }
      let(:blob_2) { create_video_blob("video2.mp4", size: 30.megabytes) }
      let(:params) { { blob_ids: [blob_1.id, blob_2.id] } }

      it "attaches videos to the report" do
        expect {
          post path, params: params, as: :json
        }.to change { report.reload.videos.count }.from(0).to(2)

        expect(response).to have_http_status(:ok)
      end

      it "broadcasts update via Turbo Stream" do
        # Mock the broadcaster
        allow_any_instance_of(ReportBroadcaster).to receive(:videos_attached)

        post path, params: params, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid blob_ids" do
      it "returns 422 when blob_ids are not found" do
        params = { blob_ids: ["invalid_id"] }

        post path, params: params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end

      it "returns 400 when blob_ids parameter is missing" do
        post path, params: {}, as: :json

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid parameters")
      end

      it "returns 400 when blob_ids is empty array" do
        params = { blob_ids: [] }

        post path, params: params, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with invalid file size" do
      let(:too_small_blob) { create_video_blob("small.mp4", size: 5.megabytes) }
      let(:params) { { blob_ids: [too_small_blob.id] } }

      it "returns 422 with error messages" do
        post path, params: params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"]).to be_an(Array)
        expect(json["errors"].first).to include("too small")
      end
    end

    context "with invalid file type" do
      let(:invalid_blob) { create_blob("document.pdf", content_type: "application/pdf", size: 20.megabytes) }
      let(:params) { { blob_ids: [invalid_blob.id] } }

      it "returns 422 with error messages" do
        post path, params: params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key("errors")
        expect(json["errors"].first).to include("not MP4 format")
      end
    end

    context "when report does not exist" do
      let(:blob) { create_video_blob("video.mp4", size: 20.megabytes) }
      let(:params) { { blob_ids: [blob.id] } }

      it "returns 404" do
        invalid_path = admin_race_report_videos_path(race, 999_999)

        post invalid_path, params: params, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authentication" do
      before { sign_out user }

      let(:blob) { create_video_blob("video.mp4", size: 20.megabytes) }
      let(:params) { { blob_ids: [blob.id] } }

      it "redirects to login" do
        post path, params: params, as: :json

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # Helper methods for creating test blobs
  def create_video_blob(filename, size:)
    create_blob(filename, content_type: "video/mp4", size: size)
  end

  def create_blob(filename, content_type:, size:)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * size),
      filename: filename,
      content_type: content_type
    )
  end
end