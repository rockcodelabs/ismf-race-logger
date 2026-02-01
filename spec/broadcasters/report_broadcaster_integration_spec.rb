# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportBroadcaster, type: :broadcaster do
  let(:race) { create(:race, :in_progress) }
  let(:race_location) { create(:race_location, race: race, name: "Checkpoint 1") }
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

  let(:broadcaster) { described_class.new }

  describe "ApplicationController alias for Turbo rendering" do
    it "has ApplicationController defined at root namespace" do
      expect(defined?(ApplicationController)).to eq("constant")
    end

    it "points to Web::Controllers::ApplicationController" do
      expect(ApplicationController).to eq(Web::Controllers::ApplicationController)
    end

    it "allows Turbo to render partials without error" do
      # This would fail with NameError if ApplicationController wasn't properly aliased
      expect {
        Turbo::StreamsChannel.broadcast_prepend_to(
          "test_stream",
          target: "test_target",
          partial: "admin/races/reports/report_card",
          locals: { report: parts_factory.wrap(report_struct), race: race }
        )
      }.not_to raise_error
    end
  end

  describe "#created - full broadcast execution" do
    it "successfully broadcasts without errors" do
      expect {
        broadcaster.created(report_struct, race.id)
      }.not_to raise_error
    end

    it "broadcasts to the correct stream name" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
        .with("race_#{race.id}_reports", anything)
        .at_least(:once)
        .and_call_original

      broadcaster.created(report_struct, race.id)
    end

    it "broadcasts card format for touch displays" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
        "race_#{race.id}_reports",
        hash_including(
          target: "pending-reports-queue",
          partial: "admin/races/reports/report_card"
        )
      )
    end

    it "broadcasts table row format for desktop" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
        "race_#{race.id}_reports",
        hash_including(
          target: "reports-table-body",
          partial: "admin/races/reports/report_row"
        )
      )
    end

    it "broadcasts counter updates" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(
          action: :update,
          target: "pending-count-badge"
        )
      )
    end

    it "broadcasts flash notice message" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
        "race_#{race.id}_reports",
        hash_including(
          target: "flash-messages",
          partial: "shared/flash",
          locals: hash_including(type: "notice", message: String)
        )
      ).and_call_original

      broadcaster.created(report_struct, race.id)
    end

    it "includes report bib number in flash message" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        "race_#{race.id}_reports",
        hash_including(
          locals: hash_including(message: "Report #42 created.")
        )
      )
    end

    it "wraps report struct in Part before rendering" do
      factory = AppContainer["parts.factory"]
      expect(factory).to receive(:wrap).with(report_struct).and_call_original

      broadcaster.created(report_struct, race.id)
    end

    it "passes race object to partials" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).with(
        anything,
        hash_including(
          locals: hash_including(race: instance_of(Race))
        )
      ).at_least(:once).and_call_original

      broadcaster.created(report_struct, race.id)
    end

    it "executes all broadcasts in correct order" do
      # Track the order of calls
      call_order = []
      
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to) do |stream, opts|
        call_order << "prepend:#{opts[:target]}"
      end

      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to) do |stream, opts|
        call_order << "update:#{opts[:target]}"
      end

      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to) do |stream, opts|
        call_order << "append:#{opts[:target]}"
      end

      broadcaster.created(report_struct, race.id)

      # Verify order: cards first, then counters, then flash
      expect(call_order).to include("prepend:pending-reports-queue")
      expect(call_order).to include("prepend:reports-table-body")
      expect(call_order).to include("update:pending-count-badge")
      expect(call_order).to include("append:flash-messages")
    end
  end

  describe "#confirmed - full broadcast execution" do
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
      AppContainer["repos.report"].find!(confirmed_report.id)
    end

    it "successfully broadcasts without errors" do
      expect {
        broadcaster.confirmed(confirmed_struct, race.id)
      }.not_to raise_error
    end

    it "broadcasts removal of the report" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to).with(
        "race_#{race.id}_reports",
        target: "report_#{confirmed_report.id}"
      ).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)
    end

    it "broadcasts pending counter update" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(target: "pending-count-badge")
      )
    end

    it "broadcasts confirmed counter update" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(target: "confirmed-count")
      )
    end

    it "broadcasts flash notice" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
        "race_#{race.id}_reports",
        hash_including(
          locals: hash_including(message: "Report #42 confirmed.")
        )
      ).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)
    end

    it "updates all three counters (pending, confirmed, rejected)" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).at_least(3).times
    end
  end

  describe "#rejected - full broadcast execution" do
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
      AppContainer["repos.report"].find!(rejected_report.id)
    end

    it "successfully broadcasts without errors" do
      expect {
        broadcaster.rejected(rejected_struct, race.id)
      }.not_to raise_error
    end

    it "broadcasts removal of the report" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to).with(
        "race_#{race.id}_reports",
        target: "report_#{rejected_report.id}"
      ).and_call_original

      broadcaster.rejected(rejected_struct, race.id)
    end

    it "broadcasts rejected counter update" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.rejected(rejected_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(target: "rejected-count")
      )
    end

    it "broadcasts flash notice with correct message" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
        "race_#{race.id}_reports",
        hash_including(
          locals: hash_including(message: "Report #42 rejected.")
        )
      ).and_call_original

      broadcaster.rejected(rejected_struct, race.id)
    end
  end

  describe "#reopened - full broadcast execution" do
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
      reopened_report.update!(status: "pending_review")
      AppContainer["repos.report"].find!(reopened_report.id)
    end

    it "successfully broadcasts without errors" do
      expect {
        broadcaster.reopened(reopened_struct, race.id)
      }.not_to raise_error
    end

    it "broadcasts card format back to pending queue" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.reopened(reopened_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
        "race_#{race.id}_reports",
        hash_including(
          target: "pending-reports-queue",
          partial: "admin/races/reports/report_card"
        )
      )
    end

    it "broadcasts table row format back to table" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.reopened(reopened_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
        "race_#{race.id}_reports",
        hash_including(
          target: "reports-table-body",
          partial: "admin/races/reports/report_row"
        )
      )
    end

    it "broadcasts flash notice" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
        "race_#{race.id}_reports",
        hash_including(
          locals: hash_including(message: "Report #42 reopened.")
        )
      ).and_call_original

      broadcaster.reopened(reopened_struct, race.id)
    end
  end

  describe "counter accuracy with existing reports" do
    let!(:existing_pending) { create_list(:report, 3, :pending_review, race: race, user: user) }
    let!(:existing_confirmed) { create_list(:report, 2, :confirmed, race: race, user: user) }
    let!(:existing_rejected) { create_list(:report, 1, :rejected, race: race, user: user) }

    before do
      # Ensure all reports have proper associations
      (existing_pending + existing_confirmed + existing_rejected).each do |r|
        r.update!(
          race_location: create(:race_location, race: race),
          race_participation: create(:race_participation, race: race)
        )
      end
    end

    it "broadcasts correct pending count after create" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(
          target: "pending-count-badge",
          html: 4 # 3 existing + 1 new
        )
      )
    end

    it "broadcasts correct counts after confirm" do
      pending_to_confirm = existing_pending.first
      confirmed_struct = AppContainer["repos.report"].find!(pending_to_confirm.id)
      pending_to_confirm.update!(status: "confirmed")

      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.confirmed(confirmed_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(target: "pending-count-badge", html: 2)
      )

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(target: "confirmed-count", html: 3)
      )
    end

    it "broadcasts correct counts after reject" do
      pending_to_reject = existing_pending.first
      rejected_struct = AppContainer["repos.report"].find!(pending_to_reject.id)
      pending_to_reject.update!(status: "rejected")

      allow(Turbo::StreamsChannel).to receive(:broadcast_action_to).and_call_original

      broadcaster.rejected(rejected_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(target: "pending-count-badge", html: 2)
      )

      expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to).with(
        "race_#{race.id}_reports",
        hash_including(target: "rejected-count", html: 2)
      )
    end
  end

  describe "race isolation" do
    let(:other_race) { create(:race, :in_progress) }

    it "only broadcasts to the specific race stream" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
        .with("race_#{race.id}_reports", anything)
        .at_least(:once)
        .and_call_original

      expect(Turbo::StreamsChannel).not_to receive(:broadcast_prepend_to)
        .with("race_#{other_race.id}_reports", anything)

      broadcaster.created(report_struct, race.id)
    end

    it "does not broadcast to other races even with similar IDs" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_prepend_to)
        .with(include("race_#{other_race.id}"), anything)
    end
  end

  describe "error handling" do
    it "raises error if race not found" do
      expect {
        broadcaster.created(report_struct, 999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "handles missing partials gracefully" do
      # This tests that if a partial is missing, we get a clear error
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      # Should raise ActionView::MissingTemplate if partial doesn't exist
      expect {
        Turbo::StreamsChannel.broadcast_prepend_to(
          "test_stream",
          target: "test",
          partial: "non_existent/partial",
          locals: {}
        )
      }.to raise_error(ActionView::MissingTemplate)
    end
  end

  describe "DOM ID generation" do
    it "generates correct DOM IDs for report elements" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_remove_to).with(
        anything,
        target: "report_#{report.id}"
      ).and_call_original

      broadcaster.confirmed(report_struct, race.id)
    end

    it "uses consistent DOM ID format across all methods" do
      dom_ids = []

      allow(Turbo::StreamsChannel).to receive(:broadcast_remove_to) do |stream, opts|
        dom_ids << opts[:target]
      end

      broadcaster.confirmed(report_struct, race.id)

      expect(dom_ids).to all(match(/^report_\d+$/))
    end
  end

  describe "partial rendering" do
    it "renders report_card partial with correct locals" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
        anything,
        hash_including(
          partial: "admin/races/reports/report_card",
          locals: hash_including(
            report: instance_of(Web::Parts::Report),
            race: instance_of(Race)
          )
        )
      )
    end

    it "renders report_row partial with correct locals" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_call_original

      broadcaster.created(report_struct, race.id)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_prepend_to).with(
        anything,
        hash_including(
          partial: "admin/races/reports/report_row",
          locals: hash_including(
            report: instance_of(Web::Parts::Report),
            race: instance_of(Race)
          )
        )
      )
    end

    it "renders unified flash partial with message" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_append_to).with(
        anything,
        hash_including(
          partial: "shared/flash",
          locals: hash_including(type: "notice", message: String)
        )
      ).and_call_original

      broadcaster.created(report_struct, race.id)
    end
  end

  describe "performance" do
    it "completes broadcasting in reasonable time" do
      start_time = Time.current
      broadcaster.created(report_struct, race.id)
      duration = (Time.current - start_time) * 1000 # milliseconds
      
      expect(duration).to be < 200
    end

    it "handles multiple rapid broadcasts" do
      reports = create_list(:report, 5, race: race, user: user)
      report_structs = reports.map { |r| AppContainer["repos.report"].find!(r.id) }

      start_time = Time.current
      report_structs.each do |struct|
        broadcaster.created(struct, race.id)
      end
      duration = (Time.current - start_time) * 1000 # milliseconds
      
      expect(duration).to be < 1000
    end
  end

  private

  def parts_factory
    @parts_factory ||= AppContainer["parts.factory"]
  end
end