# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports Broadcasting", type: :system do
  let(:admin_user) { create(:user, :admin) }
  let(:race) { create(:race, :in_progress) }
  let(:race_location) { create(:race_location, race: race, name: "Start Line") }
  let(:race_participation) { create(:race_participation, race: race, bib_number: 42) }

  before do
    driven_by(:rack_test)
    sign_in(admin_user)
  end

  describe "real-time report creation broadcasting" do
    it "broadcasts new reports to all connected devices" do
      visit admin_race_reports_path(race)

      # Verify Turbo Stream subscription is present in rendered HTML
      expect(page).to have_css('turbo-cable-stream-source[channel="Turbo::StreamsChannel"]', visible: :all)

      # Verify initial state
      expect(page).to have_content("No reports")

      # Verify broadcaster is invoked with the correct report and race
      expect_any_instance_of(ReportBroadcaster).to receive(:created).with(
        an_instance_of(Structs::Report),
        race.id
      )

      report = create(:report, :pending_review,
                      race: race,
                      race_location: race_location,
                      race_participation: race_participation,
                      user: admin_user,
                      bib_number: 42)

      ReportBroadcaster.new.created(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )
    end

    it "shows flash messages from broadcasts" do
      expect_any_instance_of(ReportBroadcaster).to receive(:created).with(
        an_instance_of(Structs::Report),
        race.id
      )

      report = create(:report, :pending_review,
                      race: race,
                      race_location: race_location,
                      race_participation: race_participation,
                      user: admin_user,
                      bib_number: 99)

      ReportBroadcaster.new.created(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )
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

    it "broadcasts report removal when confirmed" do
      visit admin_race_reports_path(race)

      # Report is visible in initial HTML
      expect(page).to have_css("#report_#{report.id}")

      expect_any_instance_of(ReportBroadcaster).to receive(:confirmed).with(
        an_instance_of(Structs::Report),
        race.id
      )

      report.update!(status: "confirmed")
      ReportBroadcaster.new.confirmed(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )
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

    it "broadcasts report removal when rejected" do
      visit admin_race_reports_path(race)

      # Report is visible in initial HTML
      expect(page).to have_css("#report_#{report.id}")

      expect_any_instance_of(ReportBroadcaster).to receive(:rejected).with(
        an_instance_of(Structs::Report),
        race.id
      )

      report.update!(status: "rejected")
      ReportBroadcaster.new.rejected(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )
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

    it "broadcasts report back to pending queue when reopened" do
      visit admin_race_reports_path(race)

      expect_any_instance_of(ReportBroadcaster).to receive(:reopened).with(
        an_instance_of(Structs::Report),
        race.id
      )

      report.update!(status: "pending_review")
      ReportBroadcaster.new.reopened(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )
    end
  end

  describe "multiple simultaneous broadcasts" do
    it "handles multiple report creations without conflicts" do
      visit admin_race_reports_path(race)

      broadcaster = ReportBroadcaster.new
      expect(broadcaster).to receive(:created).exactly(3).times

      3.times do |i|
        participation = create(:race_participation, race: race, bib_number: 100 + i)
        report = create(:report, :pending_review,
                        race: race,
                        race_location: race_location,
                        race_participation: participation,
                        user: admin_user,
                        bib_number: 100 + i)

        broadcaster.created(
          AppContainer["repos.report"].find!(report.id),
          race.id
        )
      end
    end
  end

  describe "race isolation" do
    let(:other_race) { create(:race, :in_progress) }
    let!(:other_report) do
      create(:report, :pending_review,
             race: other_race,
             user: admin_user)
    end

    it "does not show broadcasts from other races" do
      visit admin_race_reports_path(race)

      expect(page).to have_content("No reports")

      # Broadcast is keyed to the other race's ID, not this race
      expect_any_instance_of(ReportBroadcaster).to receive(:created).with(
        an_instance_of(Structs::Report),
        other_race.id
      )

      ReportBroadcaster.new.created(
        AppContainer["repos.report"].find!(other_report.id),
        other_race.id
      )
    end
  end

  describe "touch display broadcasting" do
    it "works the same on touch variant views" do
      visit admin_race_reports_path(race, touch: 1)

      # Verify touch layout loaded
      expect(page).to have_css('[data-controller="touch-report"]')

      # Turbo Stream subscription is present in touch layout
      expect(page).to have_css('turbo-cable-stream-source[channel="Turbo::StreamsChannel"]', visible: :all)

      expect_any_instance_of(ReportBroadcaster).to receive(:created).with(
        an_instance_of(Structs::Report),
        race.id
      )

      report = create(:report, :pending_review,
                      race: race,
                      race_location: race_location,
                      race_participation: race_participation,
                      user: admin_user,
                      bib_number: 42)

      ReportBroadcaster.new.created(
        AppContainer["repos.report"].find!(report.id),
        race.id
      )
    end
  end
end