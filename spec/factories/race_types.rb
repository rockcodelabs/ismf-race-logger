# frozen_string_literal: true

FactoryBot.define do
  factory :race_type do
    name { "Individual" }
    description { "Individual race format" }

    factory :race_type_individual do
      name { "Individual" }
      description { "Individual race format" }
    end

    factory :race_type_team do
      name { "Team" }
      description { "Team race format (2 athletes)" }
    end

    factory :race_type_sprint do
      name { "Sprint" }
      description { "Sprint race format with heats" }
    end

    factory :race_type_vertical do
      name { "Vertical" }
      description { "Vertical race format" }
    end

    factory :race_type_relay do
      name { "Mixed Relay" }
      description { "Mixed relay race format" }
    end
  end
end