# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportBroadcaster, type: :broadcaster do
  let(:broadcaster) { described_class.new }
  let(:race) { create(:race, :in_progress) }
  let(:race_location) { create(:race_location, race: race) }
  let(:race_participation) { create(:race_participation, race: race, bib_number: 42) }
  let(:user) { create(:user, :admin) }

  let(:report) do
    create(:report,
      race: race,
      race_location: race_location,
      race_participation: race_participation,
      user: user,
      bib_number: 42,
      status: "pending_review"
    )
  end

  let(:report_struct) do
    repo = AppContainer["repos.report"]
    repo.find!(report.id)
  end

  describe "#created" do
    it "broadcasts to the correct stream" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to)
        .with("race_#{race.id}_reports", hash_including(target: "pending-reports-queue"))
        .at_least(:once)
    end

    it "broadcasts card format for touch displays" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "pending-reports-queue",
          partial: "admin/races/reports/report_card"
        ))
    end

    it "broadcasts table row format for desktop" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "reports-table-body",
          partial: "admin/races/reports/report_row"
        ))
    end

    it "broadcasts counter updates" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "pending-count-badge"
        ))
    end

    it "broadcasts flash notice message" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "flash-messages"
        ))
    end

    it "includes report bib number in flash message" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
        .with("race_#{race.id}_reports", hash_including(
          partial: "shared/flash",
          locals: hash_including(message: include("Report #42"))
        ))
    end

    it "renders HTML from partials" do
      allow(Web::Controllers::ApplicationController).to receive(:render).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Web::Controllers::ApplicationController).to have_received(:render)
        .with(hash_including(partial: "admin/races/reports/report_card"))
        .at_least(:once)
    end
  end

  describe "#confirmed" do
    let(:confirmed_report) do
      create(:report, :confirmed,
        race: race,
        race_location: race_location,
        race_participation: race_participation,
        user: user,
        bib_number: 42
      )
    end

    let(:confirmed_struct) do
      repo = AppContainer["repos.report"]
      repo.find!(confirmed_report.id)
    end

    it "broadcasts removal of the report" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "report_#{confirmed_report.id}"
        ))
    end

    it "broadcasts pending counter update" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "pending-count-badge"
        ))
    end

    it "broadcasts confirmed counter update" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "confirmed-count"
        ))
    end

    it "broadcasts flash notice" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
        .with("race_#{race.id}_reports", hash_including(
          partial: "shared/flash",
          locals: hash_including(message: include("confirmed"))
        ))
    end
  end

  describe "#rejected" do
    let(:rejected_report) do
      create(:report, :rejected,
        race: race,
        race_location: race_location,
        race_participation: race_participation,
        user: user,
        bib_number: 42
      )
    end

    let(:rejected_struct) do
      repo = AppContainer["repos.report"]
      repo.find!(rejected_report.id)
    end

    it "broadcasts removal of the report" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to).and_call_original

      broadcaster.rejected(rejected_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "report_#{rejected_report.id}"
        ))
    end

    it "broadcasts pending counter update" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.rejected(rejected_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "pending-count-badge"
        ))
    end

    it "broadcasts rejected counter update" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.rejected(rejected_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "rejected-count"
        ))
    end

    it "broadcasts flash notice" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_call_original

      broadcaster.rejected(rejected_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
        .with("race_#{race.id}_reports", hash_including(
          partial: "shared/flash",
          locals: hash_including(message: include("rejected"))
        ))
    end
  end

  describe "#reopened" do
    let(:reopened_report) do
      create(:report, :confirmed,
        race: race,
        race_location: race_location,
        race_participation: race_participation,
        user: user,
        bib_number: 42
      )
    end

    let(:reopened_struct) do
      repo = AppContainer["repos.report"]
      repo.find!(reopened_report.id)
    end

    before do
      reopened_report.update!(status: "pending_review")
    end

    it "broadcasts card format for touch displays" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.reopened(reopened_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "pending-reports-queue",
          partial: "admin/races/reports/report_card"
        ))
    end

    it "broadcasts table row format for desktop" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.reopened(reopened_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "reports-table-body",
          partial: "admin/races/reports/report_row"
        ))
    end

    it "broadcasts counter updates" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.reopened(reopened_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "pending-count-badge"
        ))
    end

    it "broadcasts flash notice" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_call_original

      broadcaster.reopened(reopened_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
        .with("race_#{race.id}_reports", hash_including(
          partial: "shared/flash",
          locals: hash_including(message: include("reopened"))
        ))
    end
  end

  describe "stream naming" do
    it "uses race-specific stream names" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to)
        .with("race_#{race.id}_reports", anything)
        .at_least(:once)
    end

    it "isolates broadcasts to specific races" do
      other_race = create(:race, :in_progress)
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_prepend_to)
        .with("race_#{other_race.id}_reports", anything)
    end
  end

  describe "counter accuracy" do
    let!(:existing_pending) do
      create_list(:report, 2, :pending_review,
        race: race,
        race_location: race_location,
        race_participation: race_participation,
        user: user,
        bib_number: 99
      )
    end

    let!(:existing_confirmed) do
      create_list(:report, 1, :confirmed,
        race: race,
        race_location: race_location,
        race_participation: race_participation,
        user: user,
        bib_number: 88
      )
    end

    let!(:existing_rejected) do
      create_list(:report, 1, :rejected,
        race: race,
        race_location: race_location,
        race_participation: race_participation,
        user: user,
        bib_number: 77
      )
    end

    it "broadcasts correct pending count after create" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "pending-count-badge",
          html: existing_pending.count + 1
        ))
    end

    it "broadcasts correct counts after confirm" do
      confirmed_report = existing_pending.first
      confirmed_struct = AppContainer["repos.report"].find!(confirmed_report.id)
      confirmed_report.update!(status: "confirmed")

      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "pending-count-badge",
          html: existing_pending.count - 1
        ))

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "confirmed-count",
          html: existing_confirmed.count + 1
        ))
    end

    it "broadcasts correct counts after reject" do
      rejected_report = existing_pending.first
      rejected_struct = AppContainer["repos.report"].find!(rejected_report.id)
      rejected_report.update!(status: "rejected")

      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.rejected(rejected_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "pending-count-badge",
          html: existing_pending.count - 1
        ))

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "rejected-count",
          html: existing_rejected.count + 1
        ))
    end
  end

  describe "DOM ID generation" do
    it "generates correct DOM IDs for removal" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to).and_call_original

      broadcaster.confirmed(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_remove_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "report_#{report.id}"
        ))
    end
  end

  describe "part wrapping" do
    it "wraps structs in parts before rendering" do
      real_factory = Web::Parts::Factory.new
      allow(broadcaster).to receive(:parts_factory).and_return(real_factory)
      allow(real_factory).to receive(:wrap).and_call_original
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(real_factory).to have_received(:wrap).with(report_struct).at_least(:once)
    end
  end

  describe "error handling" do
    it "raises error if race not found" do
      expect {
        broadcaster.created(report_struct, 999_999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end