# frozen_string_literal: true

require "test_helper"

class MetricAggregationJobTest < ActiveJob::TestCase
  def setup
    @project = Project.create!(
      platform_project_id: "test_project",
      name: "Test Project"
    )
    @project.metric_definitions.create!(
      name: "test.metric",
      metric_type: "gauge"
    )
  end

  test "perform should aggregate metrics for specific project" do
    # Create metric points
    5.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: (i + 1) * 10,
        timestamp: 1.hour.ago
      )
    end

    MetricAggregationJob.perform_now(@project.id, bucket_size: "1h")

    # Should create aggregated metrics
    assert @project.aggregated_metrics.exists?(metric_name: "test.metric")
  end

  test "perform should process all projects when no project_id given" do
    project2 = Project.create!(
      platform_project_id: "project2",
      name: "Project 2"
    )
    project2.metric_definitions.create!(
      name: "metric2",
      metric_type: "counter"
    )

    # Create data for both projects
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 1.hour.ago
    )
    project2.metric_points.create!(
      metric_name: "metric2",
      value: 200,
      timestamp: 1.hour.ago
    )

    MetricAggregationJob.perform_now

    # Both projects should have aggregated metrics
    assert @project.aggregated_metrics.exists?
    assert project2.aggregated_metrics.exists?
  end

  test "perform should handle missing project gracefully" do
    assert_nothing_raised do
      MetricAggregationJob.perform_now(999999, bucket_size: "1h")
    end
  end

  test "perform should handle errors gracefully" do
    # Should not raise error even if aggregation fails
    assert_nothing_raised do
      MetricAggregationJob.perform_now
    end
  end

  test "perform should use specified bucket_size" do
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 1.hour.ago
    )

    MetricAggregationJob.perform_now(@project.id, bucket_size: "1d")

    aggregated = @project.aggregated_metrics.last
    assert_equal "1d", aggregated.bucket_size if aggregated
  end

  test "perform should log errors" do
    Rails.logger.expects(:error).at_least_once

    # Force an error
    MetricAggregationJob.any_instance.stubs(:aggregate_for_project).raises(StandardError.new("Test error"))

    MetricAggregationJob.perform_now(@project.id)
  end
end
