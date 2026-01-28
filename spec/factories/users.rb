# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User #{n}" }
    password { "password123" }
    password_confirmation { "password123" }
    admin { false }
    role { nil }

    trait :admin do
      admin { true }
    end

    trait :var_operator do
      role { association :role, :var_operator }
    end

    trait :national_referee do
      role { association :role, :national_referee }
    end

    trait :international_referee do
      role { association :role, :international_referee }
    end

    trait :jury_president do
      role { association :role, :jury_president }
    end

    trait :referee_manager do
      role { association :role, :referee_manager }
    end

    trait :broadcast_viewer do
      role { association :role, :broadcast_viewer }
    end

    trait :with_role do
      transient do
        role_name { %w[var_operator national_referee international_referee jury_president referee_manager broadcast_viewer].sample }
      end

      role { association :role, name: role_name }
    end
  end
end