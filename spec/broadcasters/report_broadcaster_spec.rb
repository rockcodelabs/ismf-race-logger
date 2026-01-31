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
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(action: :prepend, target: "pending-reports-queue"))
        .at_least(:once)

      broadcaster.created(report_struct, race.id)
    end

    it "broadcasts card format for touch displays" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :prepend,
          target: "pending-reports-queue"
        ))

      broadcaster.created(report_struct, race.id)
    end

    it "broadcasts table row format for desktop" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :prepend,
          target: "reports-table-body"
        ))

      broadcaster.created(report_struct, race.id)
    end

    it "broadcasts counter updates" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "pending-count-badge"
        ))

      broadcaster.created(report_struct, race.id)
    end

    it "broadcasts flash notice message" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :append,
          target: "flash-messages"
        ))

      broadcaster.created(report_struct, race.id)
    end

    it "includes report bib number in flash message" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)
      
      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          html: include("Report #42")
        ))
    end

    it "renders HTML from partials" do
      expect(Web::Controllers::ApplicationController).to receive(:render)
        .with(hash_including(partial: "admin/races/reports/report_card"))
        .and_return("<div>Report Card</div>")
      
      allow(Web::Controllers::ApplicationController).to receive(:render)
        .and_call_original

      broadcaster.created(report_struct, race.id)
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
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :remove,
          target: "report_#{confirmed_report.id}"
        ))

      broadcaster.confirmed(confirmed_struct, race.id)
    end

    it "broadcasts pending counter update" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "pending-count-badge"
        ))

      broadcaster.confirmed(confirmed_struct, race.id)
    end

    it "broadcasts confirmed counter update" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "confirmed-count"
        ))

      broadcaster.confirmed(confirmed_struct, race.id)
    end

    it "broadcasts flash notice" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          html: include("confirmed")
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
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :remove,
          target: "report_#{rejected_report.id}"
        ))

      broadcaster.rejected(rejected_struct, race.id)
    end

    it "broadcasts pending counter update" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "pending-count-badge"
        ))

      broadcaster.rejected(rejected_struct, race.id)
    end

    it "broadcasts rejected counter update" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "rejected-count"
        ))

      broadcaster.rejected(rejected_struct, race.id)
    end

    it "broadcasts flash notice" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

      broadcaster.rejected(rejected_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          html: include("rejected")
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
      # Simulate reopening (status would be pending_review after reopen operation)
      reopened_report.update!(status: "pending_review")
    end

    it "broadcasts card format for touch displays" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :prepend,
          target: "pending-reports-queue"
        ))

      broadcaster.reopened(reopened_struct, race.id)
    end

    it "broadcasts table row format for desktop" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :prepend,
          target: "reports-table-body"
        ))

      broadcaster.reopened(reopened_struct, race.id)
    end

    it "broadcasts counter updates" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          action: :update,
          target: "pending-count-badge"
        ))

      broadcaster.reopened(reopened_struct, race.id)
    end

    it "broadcasts flash notice" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

      broadcaster.reopened(reopened_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          html: include("reopened")
        ))
    end
  end

  describe "stream naming" do
    it "uses race-specific stream names" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", anything)
        .at_least(:once)

      broadcaster.created(report_struct, race.id)
    end

    it "isolates broadcasts to specific races" do
      other_race = create(:race, :in_progress)
      
      expect(Turbo::StreamsChannel).not_to receive(:broadcast_action_to)
        .with("race_#{other_race.id}_reports", anything)

      broadcaster.created(report_struct, race.id)
    end
  end

  describe "counter accuracy" do
    let!(:existing_pending) { create_list(:report, :pending_review, race: race) }
    let!(:existing_confirmed) { create_list(:report, :confirmed, race: race) }
    let!(:existing_rejected) { create_list(:report, :rejected, race: race) }

    before do
      # Create consistent reports
      existing_pending.each do |r|
        r.update!(
          race_location: create(:race_location, race: race),
          race_participation: create(:race_participation, race: race)
        )
      end
    end

    it "broadcasts correct pending count after create" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "pending-count-badge",
          html: existing_pending.count + 1 # +1 for the new report
        ))
    end

    it "broadcasts correct counts after confirm" do
      confirmed_report = existing_pending.first
      confirmed_struct = AppContainer["repos.report"].find!(confirmed_report.id)
      confirmed_report.update!(status: "confirmed")

      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

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

      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

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
      expect(Turbo::StreamsChannel).to receive(:broadcast_action_to)
        .with("race_#{race.id}_reports", hash_including(
          target: "report_#{report.id}"
        ))

      broadcaster.confirmed(report_struct, race.id)
    end
  end

  describe "part wrapping" do
    it "wraps structs in parts before rendering" do
      factory = instance_double(Web::Parts::Factory)
      allow(broadcaster).to receive(:parts_factory).and_return(factory)
      
      expect(factory).to receive(:wrap).with(report_struct).and_call_original

      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)

      broadcaster.created(report_struct, race.id)
    end
  end

  describe "error handling" do
    it "raises error if race not found" do
      expect {
        broadcaster.created(report_struct, 999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end