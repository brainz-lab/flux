# frozen_string_literal: true

FactoryBot.define do
  factory :anomaly do
    project
    source { "metric" }
    source_name { "test.metric" }
    anomaly_type { "spike" }
    severity { "warning" }
    detected_at { Time.current }
  end
end
