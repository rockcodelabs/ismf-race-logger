# frozen_string_literal: true

FactoryBot.define do
  factory :role do
    name { Role::NAMES.sample }

    trait :var_operator do
      name { "var_operator" }
    end

    trait :national_referee do
      name { "national_referee" }
    end

    trait :international_referee do
      name { "international_referee" }
    end

    trait :jury_president do
      name { "jury_president" }
    end

    trait :referee_manager do
      name { "referee_manager" }
    end

    trait :broadcast_viewer do
      name { "broadcast_viewer" }
    end
  end
end