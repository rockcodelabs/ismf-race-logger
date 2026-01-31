# frozen_string_literal: true

FactoryBot.define do
  factory :race_participation do
    association :race
    association :athlete

    sequence(:bib_number) { |n| n }
    heat { nil }
    active_in_heat { true }
    status { "registered" }
    start_time { nil }
    finish_time { nil }
    rank { nil }

    trait :registered do
      status { "registered" }
    end

    trait :started do
      status { "registered" }
      start_time { Time.current - 30.minutes }
    end

    trait :finished do
      status { "finished" }
      start_time { Time.current - 1.hour }
      finish_time { Time.current - 30.minutes }
    end

    trait :dns do
      status { "dns" }
      active_in_heat { false }
    end

    trait :dnf do
      status { "dnf" }
      start_time { Time.current - 1.hour }
      active_in_heat { false }
    end

    trait :dsq do
      status { "dsq" }
      start_time { Time.current - 1.hour }
      finish_time { Time.current - 30.minutes }
      active_in_heat { false }
    end

    trait :with_rank do
      transient do
        position { 1 }
      end

      status { "finished" }
      start_time { Time.current - 1.hour }
      finish_time { Time.current - 30.minutes }
      rank { position }
    end

    trait :in_heat do
      transient do
        heat_number { 1 }
      end

      heat { "Heat #{heat_number}" }
      active_in_heat { true }
    end

    trait :inactive_in_heat do
      active_in_heat { false }
    end
  end
end
