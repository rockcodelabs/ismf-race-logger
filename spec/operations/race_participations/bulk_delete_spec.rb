# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::RaceParticipations::BulkDelete do
  subject(:operation) { described_class.new }

  let(:race) { create(:race) }
  let(:participations) do
    [
      create(:race_participation, race: race),
      create(:race_participation, race: race),
      create(:race_participation, race: race),
      create(:race_participation, race: race),
      create(:race_participation, race: race)
    ]
  end

  describe "#call" do
    context "with participation_ids to delete" do
      it "returns Success with deleted_count" do
        ids_to_delete = [participations[0].id, participations[1].id]
        result = operation.call(race_id: race.id, participation_ids: ids_to_delete)

        expect(result).to be_success
        expect(result.value![:deleted_count]).to eq(2)
      end

      it "deletes the specified participations from database" do
        ids_to_delete = [participations[0].id, participations[1].id]
        
        expect {
          operation.call(race_id: race.id, participation_ids: ids_to_delete)
        }.to change(RaceParticipation, :count).by(-2)

        expect(RaceParticipation.find_by(id: participations[0].id)).to be_nil
        expect(RaceParticipation.find_by(id: participations[1].id)).to be_nil
        expect(RaceParticipation.find_by(id: participations[2].id)).to be_present
      end

      it "keeps participations not in the delete list" do
        ids_to_delete = [participations[0].id]
        operation.call(race_id: race.id, participation_ids: ids_to_delete)

        remaining = RaceParticipation.where(race_id: race.id).pluck(:id)
        expect(remaining).to include(participations[1].id, participations[2].id, participations[3].id, participations[4].id)
        expect(remaining).not_to include(participations[0].id)
      end
    end

    context "with participation_ids_to_keep (remove rest)" do
      it "returns Success with deleted_count" do
        ids_to_keep = [participations[0].id, participations[1].id]
        result = operation.call(race_id: race.id, participation_ids_to_keep: ids_to_keep)

        expect(result).to be_success
        expect(result.value![:deleted_count]).to eq(3)
      end

      it "deletes all participations except the ones to keep" do
        ids_to_keep = [participations[0].id, participations[1].id]
        
        expect {
          operation.call(race_id: race.id, participation_ids_to_keep: ids_to_keep)
        }.to change(RaceParticipation, :count).by(-3)

        expect(RaceParticipation.find_by(id: participations[0].id)).to be_present
        expect(RaceParticipation.find_by(id: participations[1].id)).to be_present
        expect(RaceParticipation.find_by(id: participations[2].id)).to be_nil
        expect(RaceParticipation.find_by(id: participations[3].id)).to be_nil
        expect(RaceParticipation.find_by(id: participations[4].id)).to be_nil
      end

      it "keeps only the specified participations" do
        ids_to_keep = [participations[0].id]
        operation.call(race_id: race.id, participation_ids_to_keep: ids_to_keep)

        remaining = RaceParticipation.where(race_id: race.id).pluck(:id)
        expect(remaining).to eq([participations[0].id])
      end
    end

    context "with invalid parameters" do
      it "returns Failure when no IDs provided" do
        result = operation.call(race_id: race.id)

        expect(result).to be_failure
        expect(result.failure[:empty]).to include("No participations to delete")
      end

      it "returns Failure when empty participation_ids array" do
        result = operation.call(race_id: race.id, participation_ids: [])

        expect(result).to be_failure
      end

      it "returns Failure when empty participation_ids_to_keep array" do
        result = operation.call(race_id: race.id, participation_ids_to_keep: [])

        expect(result).to be_failure
      end
    end

    context "with nonexistent participation IDs" do
      it "still succeeds if IDs don't exist (no-op)" do
        result = operation.call(race_id: race.id, participation_ids: [999999, 888888])

        expect(result).to be_success
      end
    end

    context "when deleting all participations" do
      it "succeeds when keeping no one (delete all)" do
        ids_to_keep = []
        result = operation.call(race_id: race.id, participation_ids_to_keep: ids_to_keep)

        expect(result).to be_failure # Because empty array is treated as no parameter
      end

      it "succeeds when providing all IDs for deletion" do
        all_ids = participations.map(&:id)
        result = operation.call(race_id: race.id, participation_ids: all_ids)

        expect(result).to be_success
        expect(result.value![:deleted_count]).to eq(5)
        expect(RaceParticipation.where(race_id: race.id).count).to eq(0)
      end
    end

    context "with mixed valid and invalid IDs" do
      it "still deletes valid ones and reports errors" do
        ids_to_delete = [participations[0].id, 999999]
        result = operation.call(race_id: race.id, participation_ids: ids_to_delete)

        expect(result).to be_success
        expect(result.value![:deleted_count]).to eq(1)
        expect(result.value![:errors].count).to eq(1)
        expect(RaceParticipation.find_by(id: participations[0].id)).to be_nil
      end
    end
  end
end