# frozen_string_literal: true

FactoryBot.define do
  factory :role do
    name { %w[var_operator national_referee international_referee jury_president referee_manager broadcast_viewer].sample }

    # Use initialize_with to find or create roles by name
    # This prevents unique constraint violations when creating multiple users with the same role
    initialize_with { Role.find_or_create_by(name: name) }

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
