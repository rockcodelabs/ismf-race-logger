# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Competitions::Update do
  subject(:operation) { described_class.new }

  let!(:competition) { create(:competition, :verbier) }

  describe "#call" do
    context "with valid attributes" do
      let(:valid_params) do
        {
          name: "World Cup Verbier 2025",
          city: "Verbier Updated",
          place: "Swiss Alps Updated"
        }
      end

      it "returns Success with updated Structs::Competition" do
        result = operation.call(competition.id, valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Competition)
        expect(result.value!.name).to eq("World Cup Verbier 2025")
        expect(result.value!.city).to eq("Verbier Updated")
        expect(result.value!.place).to eq("Swiss Alps Updated")
      end

      it "persists the changes to the database" do
        operation.call(competition.id, valid_params)

        updated = Competition.find(competition.id)
        expect(updated.name).to eq("World Cup Verbier 2025")
        expect(updated.city).to eq("Verbier Updated")
      end

      it "does not change unspecified fields" do
        result = operation.call(competition.id, { name: "Updated Name" })

        expect(result).to be_success
        expect(result.value!.name).to eq("Updated Name")
        expect(result.value!.city).to eq(competition.city)
        expect(result.value!.country).to eq(competition.country)
      end
    end

    context "with invalid name (blank)" do
      let(:invalid_params) do
        {
          name: ""
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(competition.id, invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:name)
      end

      it "does not persist changes" do
        original_name = competition.name
        operation.call(competition.id, invalid_params)

        expect(Competition.find(competition.id).name).to eq(original_name)
      end
    end

    context "with invalid country code" do
      let(:invalid_params) do
        {
          country: "INVALID"
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(competition.id, invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:country)
      end
    end

    context "with invalid date range (end before start)" do
      let(:invalid_params) do
        {
          start_date: Date.current + 32.days,
          end_date: Date.current + 30.days
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(competition.id, invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:end_date)
      end
    end

    context "with invalid webpage_url format" do
      let(:invalid_params) do
        {
          webpage_url: "not-a-url"
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(competition.id, invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:webpage_url)
      end
    end

    context "when competition not found" do
      it "returns Failure(:not_found)" do
        result = operation.call(999999, { name: "Updated Name" })

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end
    end

    context "when repository update fails" do
      let(:mock_repo) { instance_double(CompetitionRepo) }
      let(:operation_with_mock) { described_class.new(competition: mock_repo) }

      it "returns Failure(:update_failed)" do
        allow(mock_repo).to receive(:update).and_return(nil)

        result = operation_with_mock.call(competition.id, { name: "Updated Name" })

        expect(result).to be_failure
        expect(result.failure).to eq(:update_failed)
      end
    end

    context "updating dates" do
      let(:date_params) do
        {
          start_date: Date.new(2025, 2, 20),
          end_date: Date.new(2025, 2, 22)
        }
      end

      it "updates both dates successfully" do
        result = operation.call(competition.id, date_params)

        expect(result).to be_success
        expect(result.value!.start_date).to eq(Date.new(2025, 2, 20))
        expect(result.value!.end_date).to eq(Date.new(2025, 2, 22))
      end
    end

    context "updating description and webpage_url" do
      let(:content_params) do
        {
          description: "Updated description with more details",
          webpage_url: "https://updated-example.com"
        }
      end

      it "updates content fields successfully" do
        result = operation.call(competition.id, content_params)

        expect(result).to be_success
        expect(result.value!.description).to eq("Updated description with more details")
        expect(result.value!.webpage_url).to eq("https://updated-example.com")
      end
    end
  end

  describe "dependency injection" do
    let(:mock_repo) { instance_double(CompetitionRepo) }
    let(:operation_with_mock) { described_class.new(competition: mock_repo) }

    it "allows injecting a mock repo for testing" do
      competition_struct = Structs::Competition.new(
        id: 1,
        name: "Updated Competition",
        city: "Test City",
        place: "Test Place",
        country: "CHE",
        description: "Test description",
        start_date: Date.current + 30.days,
        end_date: Date.current + 32.days,
        webpage_url: "https://example.com",
        logo_url: nil,
        created_at: Time.current,
        updated_at: Time.current
      )

      allow(mock_repo).to receive(:update)
        .with(1, hash_including(name: "Updated Competition"))
        .and_return(competition_struct)

      result = operation_with_mock.call(1, { name: "Updated Competition" })

      expect(result).to be_success
      expect(result.value!.name).to eq("Updated Competition")
      expect(mock_repo).to have_received(:update)
    end
  end

  describe "integration with container" do
    it "can be resolved from AppContainer" do
      # The operation uses Import, so it should work with the container
      expect { described_class.new }.not_to raise_error
    end
  end
end