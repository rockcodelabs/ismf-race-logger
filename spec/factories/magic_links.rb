# frozen_string_literal: true

FactoryBot.define do
  factory :magic_link do
    association :user
    token { nil } # Let the model generate it
    expires_at { nil } # Let the model set default (15 minutes from now)
    used_at { nil }

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :used do
      expires_at { 15.minutes.from_now }
      used_at { 5.minutes.ago }
    end

    trait :valid do
      expires_at { 15.minutes.from_now }
      used_at { nil }
    end
  end
end