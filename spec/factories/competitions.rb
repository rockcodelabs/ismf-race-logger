# frozen_string_literal: true

FactoryBot.define do
  factory :competition do
    sequence(:name) { |n| "World Cup #{n}" }
    sequence(:city) { |n| "City #{n}" }
    sequence(:place) { |n| "Place #{n}" }
    country { "CHE" }
    description { "Annual ISMF competition" }
    start_date { Date.current + 30.days }
    end_date { Date.current + 32.days }
    sequence(:webpage_url) { |n| "https://example.com/competition-#{n}" }

    trait :ongoing do
      start_date { Date.current - 1.day }
      end_date { Date.current + 1.day }
    end

    trait :upcoming do
      start_date { Date.current + 30.days }
      end_date { Date.current + 32.days }
    end

    trait :past do
      start_date { Date.current - 10.days }
      end_date { Date.current - 8.days }
    end

    trait :with_logo do
      after(:create) do |competition|
        competition.logo.attach(
          io: StringIO.new("fake image data"),
          filename: "logo.png",
          content_type: "image/png"
        )
      end
    end

    trait :single_day do
      start_date { Date.current + 30.days }
      end_date { Date.current + 30.days }
    end

    trait :multi_day do
      start_date { Date.current + 30.days }
      end_date { Date.current + 35.days }
    end

    trait :verbier do
      name { "World Cup Verbier 2024" }
      city { "Verbier" }
      place { "Swiss Alps" }
      country { "CHE" }
      start_date { Date.new(2024, 1, 15) }
      end_date { Date.new(2024, 1, 17) }
      webpage_url { "https://www.ismf-ski.org" }
    end

    trait :madonna do
      name { "World Cup Madonna di Campiglio 2024" }
      city { "Madonna di Campiglio" }
      place { "Trentino" }
      country { "ITA" }
      start_date { Date.new(2024, 2, 10) }
      end_date { Date.new(2024, 2, 11) }
      webpage_url { "https://www.fisi.org" }
    end

    trait :andorra do
      name { "World Cup Andorra 2024" }
      city { "Ordino" }
      place { "Pyrenees" }
      country { "AND" }
      start_date { Date.new(2024, 3, 5) }
      end_date { Date.new(2024, 3, 7) }
      webpage_url { "https://www.skimo-andorra.com" }
    end
  end
end