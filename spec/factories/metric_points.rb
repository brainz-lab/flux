# frozen_string_literal: true

FactoryBot.define do
  factory :metric_point do
    project
    metric_name { "test.metric" }
    value { 100.0 }
    timestamp { Time.current }
    tags { {} }
  end
end
