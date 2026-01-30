# frozen_string_literal: true

FactoryBot.define do
  factory :race_location do
    association :race
    
    sequence(:name) { |n| "Location #{n}" }
    course_segment { "uphill1" }
    segment_position { "middle" }
    display_order { 10 }
    is_standard { false }
    color_code { "green" }
    description { "Test location description" }

    trait :standard do
      is_standard { true }
    end

    trait :start do
      name { "Start" }
      course_segment { "start_area" }
      segment_position { "full" }
      display_order { 0 }
      is_standard { true }
      color_code { nil }
    end

    trait :finish do
      name { "Finish" }
      course_segment { "finish_area" }
      segment_position { "full" }
      display_order { 999 }
      is_standard { true }
      color_code { nil }
    end

    trait :top do
      name { "Top 1" }
      course_segment { "uphill1" }
      segment_position { "top" }
      display_order { 10 }
      is_standard { true }
      color_code { "green" }
    end

    trait :descent do
      name { "Descent 1" }
      course_segment { "descent" }
      segment_position { "middle" }
      display_order { 50 }
      is_standard { true }
      color_code { "red" }
    end

    trait :custom do
      is_standard { false }
      name { "Camera Gate" }
      description { "Custom camera position" }
    end
  end
end