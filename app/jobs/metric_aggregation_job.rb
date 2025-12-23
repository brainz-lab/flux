# frozen_string_literal: true

class MetricAggregationJob < ApplicationJob
  queue_as :default

  def perform(project_id = nil, bucket_size: "1h")
    if project_id
      project = Project.find_by(id: project_id)
      aggregate_for_project(project, bucket_size) if project
    else
      Project.find_each do |project|
        aggregate_for_project(project, bucket_size)
      end
    end
  rescue => e
    Rails.logger.error("[MetricAggregationJob] Failed: #{e.message}")
  end

  private

  def aggregate_for_project(project, bucket_size)
    aggregator = MetricAggregator.new(project)
    aggregator.aggregate_recent(bucket_size: bucket_size)
  rescue => e
    Rails.logger.warn("[MetricAggregationJob] Aggregation failed for project #{project.id}: #{e.message}")
  end
end
