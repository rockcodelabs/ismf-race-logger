# frozen_string_literal: true

FactoryBot.define do
  factory :race_type_location_template do
    association :race_type, factory: :race_type_sprint
    
    name { "Checkpoint 1" }
    course_segment { "uphill1" }
    segment_position { "middle" }
    display_order { 0 }
    is_standard { false }
    color_code { nil }
    description { nil }

    trait :start do
      name { "Start" }
      course_segment { "start_area" }
      segment_position { "start" }
      display_order { 0 }
      is_standard { true }
      color_code { nil }
    end

    trait :finish do
      name { "Finish" }
      course_segment { "finish_area" }
      segment_position { "end" }
      display_order { 999 }
      is_standard { true }
      color_code { nil }
    end

    trait :uphill do
      name { "Top 1" }
      course_segment { "uphill1" }
      segment_position { "top" }
      is_standard { true }
      color_code { "green" }
    end

    trait :descent do
      name { "Checkpoint 1" }
      course_segment { "descent" }
      segment_position { "middle" }
      is_standard { false }
      color_code { "red" }
    end

    trait :footpart do
      name { "Checkpoint 2" }
      course_segment { "footpart" }
      segment_position { "middle" }
      is_standard { false }
      color_code { "yellow" }
    end

    trait :custom do
      name { "Camera Gate 3" }
      course_segment { "uphill1" }
      segment_position { "middle" }
      is_standard { false }
      color_code { nil }
    end

    # Sequential display order
    trait :ordered do
      sequence(:display_order)
    end
  end
end