# frozen_string_literal: true

FactoryBot.define do
  factory :widget do
    flux_dashboard
    widget_type { "number" }
    query { {} }
    display { {} }
    position { {} }
  end
end
