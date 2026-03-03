# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:platform_project_id) { |n| "prj_test_#{n}" }
    name { "Test Project" }
  end
end
