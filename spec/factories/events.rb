# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    project
    name { "test.event" }
    timestamp { Time.current }
    properties { {} }
    tags { {} }
  end
end
