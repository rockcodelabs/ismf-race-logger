# frozen_string_literal: true

FactoryBot.define do
  factory :athlete do
    sequence(:first_name) { |n| "Athlete#{n}" }
    sequence(:last_name) { |n| "Lastname#{n}" }
    sequence(:license_number) { |n| "LIC#{n.to_s.rjust(6, '0')}" }
    country { "ITA" }
    gender { "M" }

    trait :male do
      gender { "M" }
    end

    trait :female do
      gender { "F" }
    end

    trait :italian do
      country { "ITA" }
    end

    trait :french do
      country { "FRA" }
    end

    trait :swiss do
      country { "SUI" }
    end

    trait :spanish do
      country { "ESP" }
    end

    trait :austrian do
      country { "AUT" }
    end
  end
end
