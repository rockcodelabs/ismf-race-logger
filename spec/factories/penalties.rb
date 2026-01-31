# frozen_string_literal: true

FactoryBot.define do
  factory :penalty do
    sequence(:penalty_number) { |n| "TEST.#{n}" }
    sequence(:name) { |n| "Test Penalty Name #{n}" }
    category { "A" }
    category_title { "General – infringements not specifically cited" }
    category_description { "General infringement description" }
    notes { nil }

    # Penalty times for different race types
    team_individual { "60s" }
    sprint_relay { "30s" }
    vertical { "30s" }

    # Use find_or_create_by for traits that reference seeded penalties
    initialize_with do
      Penalty.find_or_create_by(penalty_number: penalty_number) do |p|
        p.name = name
        p.category = category
        p.category_title = category_title
        p.category_description = category_description
        p.notes = notes
        p.team_individual = team_individual
        p.sprint_relay = sprint_relay
        p.vertical = vertical
      end
    end

    trait :category_a do
      category { "A" }
      sequence(:penalty_number) { |n| "A#{n}" }
      category_title { "General – infringements not specifically cited" }
      name { "General infringement not specifically cited" }
    end

    trait :category_b do
      category { "B" }
      sequence(:penalty_number) { |n| "B#{n}" }
      category_title { "Equipment" }
      name { "Equipment violation" }
    end

    trait :category_c do
      category { "C" }
      sequence(:penalty_number) { |n| "C#{n}" }
      category_title { "Behaviour" }
      name { "Course and marking violation" }
    end

    trait :category_d do
      category { "D" }
      sequence(:penalty_number) { |n| "D#{n}" }
      category_title { "Team race specific" }
      name { "Team race violation" }
    end

    trait :category_e do
      category { "E" }
      sequence(:penalty_number) { |n| "E#{n}" }
      category_title { "Relay race specific" }
      name { "Relay race violation" }
    end

    trait :category_f do
      category { "F" }
      sequence(:penalty_number) { |n| "F#{n}" }
      category_title { "Coaches and officials" }
      name { "Coaches/officials violation" }
    end

    trait :dsq do
      team_individual { "DSQ" }
      sprint_relay { "DSQ" }
      vertical { "DSQ" }
    end

    trait :time_30s do
      team_individual { "30s" }
      sprint_relay { "30s" }
      vertical { "30s" }
    end

    trait :time_60s do
      team_individual { "60s" }
      sprint_relay { "60s" }
      vertical { "60s" }
    end

    trait :time_120s do
      team_individual { "120s" }
      sprint_relay { "120s" }
      vertical { "120s" }
    end

    # Common real penalties
    trait :false_start do
      category { "C" }
      penalty_number { "C.1" }
      category_title { "Behaviour" }
      name { "False start" }
      notes { "Starting before the official start signal" }
      team_individual { "60s" }
      sprint_relay { "30s" }
      vertical { "30s" }
    end

    trait :missing_equipment do
      category { "B" }
      penalty_number { "B.4" }
      category_title { "Equipment" }
      name { "Missing safety equipment or equipment not in compliance" }
      notes { "Athlete missing required safety equipment" }
      team_individual { "DSQ" }
      sprint_relay { "DSQ" }
      vertical { "DSQ" }
    end

    trait :wrong_gate do
      category { "C" }
      penalty_number { "C.4" }
      category_title { "Behaviour" }
      name { "Missing a gate in a descent section" }
      notes { "Athlete passed through incorrect gate or marker" }
      team_individual { "60s" }
      sprint_relay { "30s" }
      vertical { "30s" }
    end

    trait :early_transition do
      category { "C" }
      penalty_number { "C.23" }
      category_title { "Behaviour" }
      name { "Incorrect manoeuvre in the transition area" }
      notes { "Entering transition zone before designated area" }
      team_individual { "30s" }
      sprint_relay { "15s" }
      vertical { "15s" }
    end
  end
end
