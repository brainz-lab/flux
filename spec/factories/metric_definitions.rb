# frozen_string_literal: true

FactoryBot.define do
  factory :metric_definition do
    project
    sequence(:name) { |n| "metric.#{n}" }
    metric_type { "gauge" }
  end
end
