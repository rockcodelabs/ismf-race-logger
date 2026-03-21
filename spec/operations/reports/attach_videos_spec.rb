# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Reports::AttachVideos do
  subject(:operation) { described_class.new }

  let(:user) { create(:user) }
  let(:race) { create(:race, :in_progress) }
  let(:race_location) { create(:race_location, race: race) }
  let(:race_participation) { create(:race_participation, race: race) }
  let(:report) { create(:report, race: race, user: user, race_location: race_location, race_participation: race_participation) }

  describe "#call" do
    context "with valid video files" do
      let(:valid_blob_1) { create_video_blob("video1.mp4", size: 20.megabytes) }
      let(:valid_blob_2) { create_video_blob("video2.mp4", size: 30.megabytes) }
      let(:blob_ids) { [valid_blob_1.signed_id, valid_blob_2.signed_id] }

      it "attaches videos to the report" do
        result = operation.call(report_id: report.id, blob_ids: blob_ids)

        expect(result).to be_success
        expect(report.reload.videos.count).to eq(2)
        expect(report.videos.map(&:filename).map(&:to_s)).to contain_exactly("video1.mp4", "video2.mp4")
      end

      it "returns the updated report struct" do
        result = operation.call(report_id: report.id, blob_ids: blob_ids)

        expect(result).to be_success
        report_struct = result.success
        expect(report_struct).to be_a(Structs::Report)
        expect(report_struct.id).to eq(report.id)
      end

      it "accepts small video files (no minimum size restriction)" do
        small_blob = create_video_blob("small.mp4", size: 1.megabyte)
        result = operation.call(report_id: report.id, blob_ids: [small_blob.signed_id])

        expect(result).to be_success
        expect(report.reload.videos.count).to eq(1)
      end
    end

    context "with invalid file size" do
      let(:too_large_blob) { create_video_blob("large.mp4", size: 501.megabytes) }

      it "fails for files that are too large" do
        result = operation.call(report_id: report.id, blob_ids: [too_large_blob.signed_id])

        expect(result).to be_failure
        expect(result.failure).to have_key(:invalid_files)
        expect(result.failure[:invalid_files]).to include(/too large/)
      end
    end

    context "with invalid file type" do
      let(:invalid_blob) { create_blob("document.pdf", content_type: "application/pdf", size: 20.megabytes) }

      it "fails for non-video files" do
        result = operation.call(report_id: report.id, blob_ids: [invalid_blob.signed_id])

        expect(result).to be_failure
        expect(result.failure).to have_key(:invalid_files)
        expect(result.failure[:invalid_files]).to include(/unsupported format/)
      end
    end

    context "with invalid inputs" do
      let(:valid_blob) { create_video_blob("video.mp4", size: 20.megabytes) }

      it "fails when report_id is missing" do
        result = operation.call(report_id: nil, blob_ids: [valid_blob.signed_id])

        expect(result).to be_failure
        expect(result.failure).to eq(:missing_report_id)
      end

      it "fails when blob_ids is missing" do
        result = operation.call(report_id: report.id, blob_ids: nil)

        expect(result).to be_failure
        expect(result.failure).to eq(:missing_blob_ids)
      end

      it "fails when blob_ids is empty" do
        result = operation.call(report_id: report.id, blob_ids: [])

        expect(result).to be_failure
        expect(result.failure).to eq(:missing_blob_ids)
      end
    end

    context "when report does not exist" do
      let(:valid_blob) { create_video_blob("video.mp4", size: 20.megabytes) }

      it "fails with not_found" do
        result = operation.call(report_id: 999_999, blob_ids: [valid_blob.signed_id])

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end
    end

    context "when blobs do not exist" do
      it "fails with blobs_not_found" do
        result = operation.call(report_id: report.id, blob_ids: ["invalid_signed_blob_id"])

        expect(result).to be_failure
        expect(result.failure).to eq(:blobs_not_found)
      end
    end

    context "with mixed valid and invalid files" do
      let(:valid_blob) { create_video_blob("valid.mp4", size: 20.megabytes) }
      let(:invalid_blob) { create_blob("doc.pdf", content_type: "application/pdf", size: 20.megabytes) }

      it "fails and reports all errors" do
        result = operation.call(report_id: report.id, blob_ids: [valid_blob.signed_id, invalid_blob.signed_id])

        expect(result).to be_failure
        expect(result.failure).to have_key(:invalid_files)
        expect(result.failure[:invalid_files].size).to eq(1)
        expect(result.failure[:invalid_files].first).to include("doc.pdf")
      end

      it "does not attach any files when validation fails" do
        operation.call(report_id: report.id, blob_ids: [valid_blob.signed_id, invalid_blob.signed_id])

        expect(report.reload.videos.count).to eq(0)
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