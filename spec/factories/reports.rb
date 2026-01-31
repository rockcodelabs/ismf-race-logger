# frozen_string_literal: true

FactoryBot.define do
  factory :report do
    association :race
    association :user
    association :race_location
    association :race_participation

    sequence(:bib_number) { |n| n }
    client_uuid { SecureRandom.uuid }
    athlete_position { nil }
    description { nil }
    status { "pending_review" }

    # Set bib_number from race_participation if not explicitly set
    after(:build) do |report|
      report.bib_number ||= report.race_participation&.bib_number || 1
    end

    trait :pending_review do
      status { "pending_review" }
    end

    trait :confirmed do
      status { "confirmed" }
    end

    trait :rejected do
      status { "rejected" }
    end

    trait :with_description do
      description { "Observed potential infringement at this location" }
    end

    trait :with_athlete_position do
      transient do
        position { 1 }
      end

      athlete_position { position }
    end

    trait :linked_to_incident do
      association :incident
      status { "confirmed" }
    end

    # Create a fully consistent report with race, location, and participation all linked
    trait :consistent do
      transient do
        target_race { nil }
      end

      after(:build) do |report, evaluator|
        if evaluator.target_race
          report.race = evaluator.target_race
          report.race_location = create(:race_location, race: evaluator.target_race) unless report.race_location&.race_id == evaluator.target_race.id
          report.race_participation = create(:race_participation, race: evaluator.target_race) unless report.race_participation&.race_id == evaluator.target_race.id
          report.bib_number = report.race_participation.bib_number
        end
      end
    end
  end
end
