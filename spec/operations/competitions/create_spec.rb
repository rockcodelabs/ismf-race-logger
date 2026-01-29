# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Competitions::Create do
  subject(:operation) { described_class.new }

  describe "#call" do
    context "with valid attributes" do
      let(:valid_params) do
        {
          name: "World Cup Verbier 2024",
          city: "Verbier",
          place: "Swiss Alps",
          country: "CHE",
          description: "Annual ISMF World Cup competition in the Swiss Alps",
          start_date: Date.new(2024, 1, 15),
          end_date: Date.new(2024, 1, 17),
          webpage_url: "https://www.ismf-ski.org"
        }
      end

      it "returns Success with a Structs::Competition" do
        result = operation.call(valid_params)

        expect(result).to be_success
        expect(result.value!).to be_a(Structs::Competition)
        expect(result.value!.name).to eq("World Cup Verbier 2024")
        expect(result.value!.city).to eq("Verbier")
        expect(result.value!.country).to eq("CHE")
      end

      it "persists the competition to the database" do
        expect {
          operation.call(valid_params)
        }.to change(Competition, :count).by(1)
      end
    end

    context "with invalid name (blank)" do
      let(:invalid_params) do
        {
          name: "",
          city: "Verbier",
          place: "Swiss Alps",
          country: "CHE",
          description: "Test",
          start_date: Date.current + 30.days,
          end_date: Date.current + 32.days,
          webpage_url: "https://example.com"
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:name)
      end

      it "does not persist to database" do
        expect {
          operation.call(invalid_params)
        }.not_to change(Competition, :count)
      end
    end

    context "with invalid country code" do
      let(:invalid_params) do
        {
          name: "Test Competition",
          city: "Test City",
          place: "Test Place",
          country: "INVALID",
          description: "Test",
          start_date: Date.current + 30.days,
          end_date: Date.current + 32.days,
          webpage_url: "https://example.com"
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:country)
      end
    end

    context "with invalid date range (end before start)" do
      let(:invalid_params) do
        {
          name: "Test Competition",
          city: "Test City",
          place: "Test Place",
          country: "CHE",
          description: "Test",
          start_date: Date.current + 32.days,
          end_date: Date.current + 30.days,
          webpage_url: "https://example.com"
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:end_date)
      end
    end

    context "with invalid webpage_url format" do
      let(:invalid_params) do
        {
          name: "Test Competition",
          city: "Test City",
          place: "Test Place",
          country: "CHE",
          description: "Test",
          start_date: Date.current + 30.days,
          end_date: Date.current + 32.days,
          webpage_url: "not-a-url"
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
        expect(result.failure.last).to have_key(:webpage_url)
      end
    end

    context "with missing required fields" do
      let(:invalid_params) do
        {
          name: "Test Competition"
        }
      end

      it "returns Failure with validation errors" do
        result = operation.call(invalid_params)

        expect(result).to be_failure
        expect(result.failure).to be_an(Array)
        expect(result.failure.first).to eq(:validation_failed)
      end
    end

    context "with all optional fields provided" do
      let(:complete_params) do
        {
          name: "World Cup Verbier 2024",
          city: "Verbier",
          place: "Swiss Alps",
          country: "CHE",
          description: "Annual ISMF World Cup competition in the Swiss Alps",
          start_date: Date.new(2024, 1, 15),
          end_date: Date.new(2024, 1, 17),
          webpage_url: "https://www.ismf-ski.org"
        }
      end

      it "creates competition with all fields" do
        result = operation.call(complete_params)

        expect(result).to be_success
        expect(result.value!.description).to eq("Annual ISMF World Cup competition in the Swiss Alps")
        expect(result.value!.webpage_url).to eq("https://www.ismf-ski.org")
      end
    end
  end

  describe "dependency injection" do
    let(:mock_repo) { instance_double(CompetitionRepo) }
    let(:operation_with_mock) { described_class.new(competition: mock_repo) }

    it "allows injecting a mock repo for testing" do
      competition_struct = Structs::Competition.new(
        id: 1,
        name: "Test Competition",
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

      allow(mock_repo).to receive(:create)
        .with(hash_including(name: "Test Competition"))
        .and_return(competition_struct)

      result = operation_with_mock.call(
        name: "Test Competition",
        city: "Test City",
        place: "Test Place",
        country: "CHE",
        description: "Test description",
        start_date: Date.current + 30.days,
        end_date: Date.current + 32.days,
        webpage_url: "https://example.com"
      )

      expect(result).to be_success
      expect(result.value!.name).to eq("Test Competition")
      expect(mock_repo).to have_received(:create)
    end

    it "returns failure when mock repo returns nil" do
      allow(mock_repo).to receive(:create).and_return(nil)

      result = operation_with_mock.call(
        name: "Test Competition",
        city: "Test City",
        place: "Test Place",
        country: "CHE",
        description: "Test",
        start_date: Date.current + 30.days,
        end_date: Date.current + 32.days,
        webpage_url: "https://example.com"
      )

      expect(result).to be_failure
      expect(result.failure).to eq(:create_failed)
    end
  end

  describe "integration with container" do
    it "can be resolved from AppContainer" do
      # The operation uses Import, so it should work with the container
      expect { described_class.new }.not_to raise_error
    end
  end
end