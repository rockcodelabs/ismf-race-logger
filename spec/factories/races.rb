# frozen_string_literal: true

FactoryBot.define do
  factory :race do
    association :competition
    association :race_type, factory: [:race_type, :individual]
    
    sequence(:name) { |n| "Race #{n}" }
    stage { "qualification" }
    start_time { Time.current + 2.hours }
    position { 1 }
    status { "scheduled" }

    trait :scheduled do
      status { "scheduled" }
      start_time { Time.current + 2.hours }
    end

    trait :in_progress do
      status { "in_progress" }
      start_time { Time.current - 1.hour }
    end

    trait :completed do
      status { "completed" }
      start_time { Time.current - 3.hours }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :qualification do
      stage { "qualification" }
      name { "Qualification" }
    end

    trait :semifinal do
      stage { "semifinal" }
      name { "Semifinal" }
    end

    trait :final do
      stage { "final" }
      name { "Final" }
    end

    trait :individual do
      association :race_type, factory: [:race_type, :individual]
      name { "Individual #{stage.titleize}" }
    end

    trait :sprint do
      association :race_type, factory: [:race_type, :sprint]
      name { "Sprint #{stage.titleize}" }
    end

    trait :vertical do
      association :race_type, factory: [:race_type, :vertical]
      name { "Vertical #{stage.titleize}" }
    end

    trait :relay do
      association :race_type, factory: [:race_type, :relay]
      name { "Relay #{stage.titleize}" }
    end
  end
end