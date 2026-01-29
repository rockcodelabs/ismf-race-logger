# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Competitions::Destroy do
  subject(:operation) { described_class.new }

  describe "#call" do
    context "when competition exists" do
      let!(:competition) { create(:competition, :verbier) }

      it "returns Success" do
        result = operation.call(competition.id)

        expect(result).to be_success
      end

      it "deletes the competition from the database" do
        expect {
          operation.call(competition.id)
        }.to change(Competition, :count).by(-1)
      end

      it "removes the competition permanently" do
        operation.call(competition.id)

        expect(Competition.exists?(competition.id)).to be false
      end
    end

    context "when competition does not exist" do
      it "returns Failure(:not_found)" do
        result = operation.call(999999)

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end

      it "does not affect database" do
        expect {
          operation.call(999999)
        }.not_to change(Competition, :count)
      end
    end

    context "when competition has associated races" do
      let!(:competition) { create(:competition) }

      before do
        # Create races associated with the competition
        competition.races.create!(
          name: "Individual Race",
          race_type: "individual",
          stage: "qualification",
          start_time: competition.start_date.to_time
        )
        competition.races.create!(
          name: "Sprint Race",
          race_type: "sprint",
          stage: "final",
          start_time: competition.start_date.to_time + 2.hours
        )
      end

      it "deletes the competition and cascades to races" do
        expect {
          operation.call(competition.id)
        }.to change(Competition, :count).by(-1)

        # Races should be deleted via dependent: :destroy
        expect(competition.races.reload).to be_empty
      end
    end

    context "when competition has attached logo" do
      let!(:competition) { create(:competition, :with_logo) }

      it "deletes the competition and purges the logo" do
        expect(competition.logo).to be_attached

        result = operation.call(competition.id)

        expect(result).to be_success
        expect(Competition.exists?(competition.id)).to be false
      end
    end

    context "when repository delete fails" do
      let(:mock_repo) { instance_double(CompetitionRepo) }
      let(:operation_with_mock) { described_class.new(competition: mock_repo) }

      it "returns Failure(:delete_failed)" do
        allow(mock_repo).to receive(:delete).and_return(false)

        result = operation_with_mock.call(123)

        expect(result).to be_failure
        expect(result.failure).to eq(:delete_failed)
      end
    end
  end

  describe "dependency injection" do
    let(:mock_repo) { instance_double(CompetitionRepo) }
    let(:operation_with_mock) { described_class.new(competition: mock_repo) }

    it "allows injecting a mock repo for testing" do
      allow(mock_repo).to receive(:delete).with(1).and_return(true)

      result = operation_with_mock.call(1)

      expect(result).to be_success
      expect(mock_repo).to have_received(:delete).with(1)
    end

    it "returns failure when mock repo returns nil" do
      allow(mock_repo).to receive(:delete).with(999).and_return(nil)

      result = operation_with_mock.call(999)

      expect(result).to be_failure
      expect(result.failure).to eq(:not_found)
    end
  end

  describe "integration with container" do
    it "can be resolved from AppContainer" do
      # The operation uses Import, so it should work with the container
      expect { described_class.new }.not_to raise_error
    end
  end
end