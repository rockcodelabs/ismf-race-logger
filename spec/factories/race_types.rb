# frozen_string_literal: true

FactoryBot.define do
  factory :race_type do
    trait :individual do
      name { "individual" }
      description { "Individual race" }
    end

    trait :sprint do
      name { "sprint" }
      description { "Sprint race" }
    end

    trait :vertical do
      name { "vertical" }
      description { "Vertical race" }
    end

    trait :relay do
      name { "relay" }
      description { "Relay race" }
    end
  end
end