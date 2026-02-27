# frozen_string_literal: true

FactoryBot.define do
  factory :aggregated_metric do
    project
    metric_name { "test.metric" }
    bucket_size { "1h" }
    bucket_time { 1.hour.ago.beginning_of_hour }
    count { 10 }
    sum { 500.0 }
    avg { 50.0 }
    min { 10.0 }
    max { 100.0 }
  end
end
