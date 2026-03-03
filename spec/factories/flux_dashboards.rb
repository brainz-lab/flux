# frozen_string_literal: true

FactoryBot.define do
  factory :flux_dashboard do
    project
    sequence(:name) { |n| "Dashboard #{n}" }
  end
end
