# frozen_string_literal: true

FactoryBot.define do
  factory :race do
    association :competition
    association :race_type
    
    sequence(:name) { |n| "Race #{n}" }
    stage_type { "Qualification" }
    stage_name { "Qualification" }
    heat_number { nil }
    scheduled_at { Time.current + 2.hours }
    position { 0 }
    status { "scheduled" }

    # Automatically set stage_name based on stage_type and heat_number
    after(:build) do |race|
      if race.heat_number.present?
        race.stage_name = "#{race.stage_type} #{race.heat_number}"
      else
        race.stage_name = race.stage_type
      end
    end

    trait :scheduled do
      status { "scheduled" }
      scheduled_at { Time.current + 2.hours }
    end

    trait :in_progress do
      status { "in_progress" }
      scheduled_at { Time.current - 1.hour }
    end

    trait :completed do
      status { "completed" }
      scheduled_at { Time.current - 3.hours }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :qualification do
      stage_type { "Qualification" }
      stage_name { "Qualification" }
      name { "Qualification" }
    end

    trait :heat do
      stage_type { "Heat" }
      heat_number { 1 }
      stage_name { "Heat 1" }
      name { "Heat 1" }
    end

    trait :quarterfinal do
      stage_type { "Quarterfinal" }
      heat_number { 1 }
      stage_name { "Quarterfinal 1" }
      name { "Quarterfinal 1" }
    end

    trait :semifinal do
      stage_type { "Semifinal" }
      heat_number { 1 }
      stage_name { "Semifinal 1" }
      name { "Semifinal 1" }
    end

    trait :final do
      stage_type { "Final" }
      stage_name { "Final" }
      name { "Final" }
    end

    trait :with_heat_number do
      heat_number { 1 }
    end

    trait :individual do
      association :race_type, factory: :race_type_individual
      name { "Individual #{stage_type}" }
    end

    trait :sprint do
      association :race_type, factory: :race_type_sprint
      name { "Sprint #{stage_type}" }
    end

    trait :vertical do
      association :race_type, factory: :race_type_vertical
      name { "Vertical #{stage_type}" }
    end

    trait :team do
      association :race_type, factory: :race_type_team
      name { "Team #{stage_type}" }
    end

    trait :relay do
      association :race_type, factory: :race_type_relay
      name { "Mixed Relay #{stage_type}" }
    end
  end
end