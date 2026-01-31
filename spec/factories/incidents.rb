# frozen_string_literal: true

FactoryBot.define do
  factory :incident do
    association :race
    race_location { nil }

    client_uuid { SecureRandom.uuid }
    status { "pending" }
    description { nil }
    decided_at { nil }
    decided_by_user { nil }

    trait :pending do
      status { "pending" }
      decided_at { nil }
      decided_by_user { nil }
    end

    trait :approved do
      status { "approved" }
      decided_at { Time.current }
      association :decided_by_user, factory: :user
    end

    trait :rejected do
      status { "rejected" }
      decided_at { Time.current }
      association :decided_by_user, factory: :user
    end

    trait :with_description do
      description { "Incident description with details about what happened" }
    end

    trait :with_location do
      race_location { association :race_location, race: race }
    end

    trait :with_reports do
      transient do
        reports_count { 2 }
      end

      after(:create) do |incident, evaluator|
        create_list(:report, evaluator.reports_count,
                    race: incident.race,
                    race_location: incident.race_location || create(:race_location, race: incident.race),
                    incident: incident,
                    status: "confirmed")
      end
    end

    trait :with_penalties do
      transient do
        penalties_count { 1 }
      end

      after(:create) do |incident, evaluator|
        penalties = create_list(:penalty, evaluator.penalties_count)
        penalties.each do |penalty|
          create(:incident_penalty, incident: incident, penalty: penalty)
        end
      end
    end

    # Create a fully consistent incident with all associations
    trait :complete do
      transient do
        target_race { nil }
      end

      status { "approved" }
      decided_at { Time.current }
      association :decided_by_user, factory: :user

      after(:build) do |incident, evaluator|
        if evaluator.target_race
          incident.race = evaluator.target_race
          incident.race_location = create(:race_location, race: evaluator.target_race)
        end
      end

      after(:create) do |incident|
        # Add a couple of linked reports
        2.times do
          participation = create(:race_participation, race: incident.race)
          create(:report,
                 race: incident.race,
                 race_location: incident.race_location,
                 race_participation: participation,
                 bib_number: participation.bib_number,
                 incident: incident,
                 status: "confirmed")
        end

        # Add a penalty
        penalty = create(:penalty, :false_start)
        create(:incident_penalty, incident: incident, penalty: penalty)
      end
    end
  end

  factory :incident_penalty do
    association :incident
    association :penalty
  end
end
