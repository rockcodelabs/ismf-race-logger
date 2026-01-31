# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports Broadcasting", type: :system, js: true do
  let(:admin_user) { create(:user, :admin) }
  let(:race) { create(:race, :in_progress) }
  let(:race_location) { create(:race_location, race: race, name: "Start Line") }
  let(:race_participation) { create(:race_participation, race: race, bib_number: 42) }

  before do
    # Ensure ActionCable is configured for testing
    allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original
    
    sign_in(admin_user)
  end

  describe "real-time report creation broadcasting" do
    it "broadcasts new reports to all connected devices", :aggregate_failures do
      visit admin_race_reports_path(race)

      # Verify Turbo Stream subscription is present
      expect(page).to have_css('turbo-cable-stream-source[channel="Turbo::StreamsChannel"]', visible: false)

      # Initial state
      expect(page).to have_content("No reports")
      pending_badge = find("#pending-count-badge")
      expect(pending_badge.text).to eq("0")

      # Simulate another device creating a report (via broadcaster)
      report = create(:report, :pending_review,
                      race: race,
                      race_location: race_location,
                      race_participation: race_participation,
                      user: admin_user,
                      bib_number: 42)

      # Trigger the broadcast as if another device created it
      broadcaster = ReportBroadcaster.new
      broadcaster.created(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )

      # Wait for broadcast to be processed (ActionCable + Turbo)
      sleep 0.5

      # Verify the report appears without page reload
      expect(page).to have_css("#report_#{report.id}", wait: 2)
      expect(page).to have_content("42")
      expect(page).to have_content("Start Line")

      # Verify counter was updated
      expect(pending_badge.text).to eq("1")
    end

    it "shows flash messages from broadcasts", :aggregate_failures do
      visit admin_race_reports_path(race)

      # Create report via broadcast
      report = create(:report, :pending_review,
                      race: race,
                      race_location: race_location,
                      race_participation: race_participation,
                      user: admin_user,
                      bib_number: 99)

      broadcaster = ReportBroadcaster.new
      broadcaster.created(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )

      # Wait for flash message to appear
      expect(page).to have_content("Report #99 created", wait: 2)
    end
  end

  describe "real-time report confirmation broadcasting" do
    let!(:report) do
      create(:report, :pending_review,
             race: race,
             race_location: race_location,
             race_participation: race_participation,
             user: admin_user,
             bib_number: 42)
    end

    it "broadcasts report removal when confirmed", :aggregate_failures do
      visit admin_race_reports_path(race)

      # Verify report is visible
      expect(page).to have_css("#report_#{report.id}")
      pending_badge = find("#pending-count-badge")
      expect(pending_badge.text).to eq("1")

      confirmed_badge = find("#confirmed-count")
      expect(confirmed_badge.text).to eq("0")

      # Simulate another device confirming the report
      report.update!(status: "confirmed")
      broadcaster = ReportBroadcaster.new
      broadcaster.confirmed(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )

      # Wait for broadcast
      sleep 0.5

      # Verify report was removed
      expect(page).not_to have_css("#report_#{report.id}", wait: 2)

      # Verify counters updated
      expect(pending_badge.text).to eq("0")
      expect(confirmed_badge.text).to eq("1")

      # Verify flash message
      expect(page).to have_content("Report #42 confirmed", wait: 2)
    end
  end

  describe "real-time report rejection broadcasting" do
    let!(:report) do
      create(:report, :pending_review,
             race: race,
             race_location: race_location,
             race_participation: race_participation,
             user: admin_user,
             bib_number: 42)
    end

    it "broadcasts report removal when rejected", :aggregate_failures do
      visit admin_race_reports_path(race)

      # Verify initial state
      expect(page).to have_css("#report_#{report.id}")
      pending_badge = find("#pending-count-badge")
      rejected_badge = find("#rejected-count")
      expect(pending_badge.text).to eq("1")
      expect(rejected_badge.text).to eq("0")

      # Simulate another device rejecting the report
      report.update!(status: "rejected")
      broadcaster = ReportBroadcaster.new
      broadcaster.rejected(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )

      # Wait for broadcast
      sleep 0.5

      # Verify report was removed
      expect(page).not_to have_css("#report_#{report.id}", wait: 2)

      # Verify counters updated
      expect(pending_badge.text).to eq("0")
      expect(rejected_badge.text).to eq("1")

      # Verify flash message
      expect(page).to have_content("Report #42 rejected", wait: 2)
    end
  end

  describe "real-time report reopening broadcasting" do
    let!(:report) do
      create(:report, :confirmed,
             race: race,
             race_location: race_location,
             race_participation: race_participation,
             user: admin_user,
             bib_number: 42)
    end

    it "broadcasts report back to pending queue when reopened", :aggregate_failures do
      visit admin_race_reports_path(race)

      # Initial state - no pending reports
      pending_badge = find("#pending-count-badge")
      confirmed_badge = find("#confirmed-count")
      expect(pending_badge.text).to eq("0")
      expect(confirmed_badge.text).to eq("1")

      # Simulate another device reopening the report
      report.update!(status: "pending_review")
      broadcaster = ReportBroadcaster.new
      broadcaster.reopened(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )

      # Wait for broadcast
      sleep 0.5

      # Verify report appears in pending queue
      expect(page).to have_css("#report_#{report.id}", wait: 2)
      expect(page).to have_content("42")

      # Verify counters updated
      expect(pending_badge.text).to eq("1")
      expect(confirmed_badge.text).to eq("0")

      # Verify flash message
      expect(page).to have_content("Report #42 reopened", wait: 2)
    end
  end

  describe "multiple simultaneous broadcasts" do
    it "handles multiple report creations without conflicts", :aggregate_failures do
      visit admin_race_reports_path(race)

      pending_badge = find("#pending-count-badge")
      expect(pending_badge.text).to eq("0")

      # Create 3 reports rapidly
      reports = []
      3.times do |i|
        participation = create(:race_participation, race: race, bib_number: 100 + i)
        report = create(:report, :pending_review,
                        race: race,
                        race_location: race_location,
                        race_participation: participation,
                        user: admin_user,
                        bib_number: 100 + i)
        reports << report

        broadcaster = ReportBroadcaster.new
        broadcaster.created(
          AppContainer["repos.report"].find!(report.id),
          race.id
        )
      end

      # Wait for all broadcasts
      sleep 1

      # Verify all reports appear
      reports.each do |report|
        expect(page).to have_css("#report_#{report.id}", wait: 2)
      end

      # Verify counter shows correct total
      expect(pending_badge.text).to eq("3")
    end
  end

  describe "race isolation" do
    let(:other_race) { create(:race, :in_progress) }
    let!(:other_report) do
      create(:report, :pending_review,
             race: other_race,
             user: admin_user)
    end

    it "does not show broadcasts from other races", :aggregate_failures do
      visit admin_race_reports_path(race)

      expect(page).to have_content("No reports")
      pending_badge = find("#pending-count-badge")
      expect(pending_badge.text).to eq("0")

      # Broadcast a report for the OTHER race
      broadcaster = ReportBroadcaster.new
      broadcaster.created(
        AppContainer["repos.report"].find!(other_report.id),
        other_race.id
      )

      # Wait
      sleep 0.5

      # Verify nothing changed on this race's page
      expect(page).to have_content("No reports")
      expect(pending_badge.text).to eq("0")
      expect(page).not_to have_css("#report_#{other_report.id}")
    end
  end

  describe "touch display broadcasting" do
    it "works the same on touch variant views", :aggregate_failures do
      # Visit with touch parameter
      visit admin_race_reports_path(race, touch: 1)

      # Verify touch layout loaded
      expect(page).to have_css('[data-controller="touch-report"]')

      # Create report via broadcast
      report = create(:report, :pending_review,
                      race: race,
                      race_location: race_location,
                      race_participation: race_participation,
                      user: admin_user,
                      bib_number: 42)

      broadcaster = ReportBroadcaster.new
      broadcaster.created(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )

      # Wait for broadcast
      sleep 0.5

      # Verify report card appears in pending queue
      expect(page).to have_css("#report_#{report.id}", wait: 2)
      expect(page).to have_content("42")

      # Verify counter updated
      pending_badge = find("#pending-count-badge")
      expect(pending_badge.text).to eq("1")
    end
  end
end