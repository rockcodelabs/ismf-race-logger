# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User #{n}" }
    password { "password123" }
    password_confirmation { "password123" }
    admin { false }

    trait :admin do
      admin { true }
    end
  end
end