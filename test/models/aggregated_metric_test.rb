# frozen_string_literal: true

require "test_helper"

class AggregatedMetricTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(platform_project_id: "test_project", name: "Test")
    @aggregated_metric = @project.aggregated_metrics.create!(
      metric_name: "api.requests",
      bucket_size: "1h",
      bucket_time: 1.hour.ago.beginning_of_hour,
      count: 150,
      sum: 1500,
      avg: 10.0,
      min: 5.0,
      max: 20.0
    )
  end

  test "should be valid with valid attributes" do
    assert @aggregated_metric.valid?
  end

  test "should require metric_name" do
    metric = @project.aggregated_metrics.new(
      bucket_size: "1h",
      bucket_time: Time.current
    )
    assert_not metric.valid?
    assert_includes metric.errors[:metric_name], "can't be blank"
  end

  test "should require bucket_size" do
    metric = @project.aggregated_metrics.new(
      metric_name: "test",
      bucket_time: Time.current
    )
    assert_not metric.valid?
    assert_includes metric.errors[:bucket_size], "can't be blank"
  end

  test "should validate bucket_size is in allowed sizes" do
    metric = @project.aggregated_metrics.new(
      metric_name: "test",
      bucket_size: "invalid",
      bucket_time: Time.current
    )
    assert_not metric.valid?
    assert_includes metric.errors[:bucket_size], "is not included in the list"
  end

  test "should allow 1m bucket size" do
    metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1m",
      bucket_time: Time.current
    )
    assert metric.valid?
  end

  test "should allow 5m bucket size" do
    metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "5m",
      bucket_time: Time.current
    )
    assert metric.valid?
  end

  test "should allow 1h bucket size" do
    metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1h",
      bucket_time: Time.current
    )
    assert metric.valid?
  end

  test "should allow 1d bucket size" do
    metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1d",
      bucket_time: Time.current
    )
    assert metric.valid?
  end

  test "should require bucket_time" do
    metric = @project.aggregated_metrics.new(
      metric_name: "test",
      bucket_size: "1h"
    )
    assert_not metric.valid?
    assert_includes metric.errors[:bucket_time], "can't be blank"
  end

  test "should belong to project" do
    assert_equal @project, @aggregated_metric.project
  end

  test "by_metric scope should filter by metric name" do
    @project.aggregated_metrics.create!(
      metric_name: "other",
      bucket_size: "1h",
      bucket_time: Time.current
    )

    metrics = @project.aggregated_metrics.by_metric("api.requests")
    assert_equal 1, metrics.count
    assert_equal "api.requests", metrics.first.metric_name
  end

  test "by_bucket scope should filter by bucket size" do
    @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1d",
      bucket_time: Time.current
    )

    metrics = @project.aggregated_metrics.by_bucket("1h")
    assert_equal 1, metrics.count
    assert_equal "1h", metrics.first.bucket_size
  end

  test "since scope should filter by bucket_time" do
    old_metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1h",
      bucket_time: 2.days.ago
    )
    new_metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1h",
      bucket_time: 1.hour.ago
    )

    metrics = @project.aggregated_metrics.since(1.day.ago)
    assert_includes metrics, new_metric
    assert_not_includes metrics, old_metric
  end

  test "until_time scope should filter by bucket_time" do
    old_metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1h",
      bucket_time: 2.days.ago
    )
    new_metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1h",
      bucket_time: 1.hour.ago
    )

    metrics = @project.aggregated_metrics.until_time(1.day.ago)
    assert_includes metrics, old_metric
    assert_not_includes metrics, new_metric
  end

  test "for_chart should return time series data" do
    3.times do |i|
      @project.aggregated_metrics.create!(
        metric_name: "chart_metric",
        bucket_size: "1h",
        bucket_time: i.hours.ago.beginning_of_hour,
        avg: i * 10.0
      )
    end

    data = AggregatedMetric.where(project: @project).for_chart(
      "chart_metric",
      bucket_size: "1h",
      since: 5.hours.ago
    )

    assert_kind_of Array, data
    assert data.size > 0
    assert_kind_of Array, data.first
    assert_equal 2, data.first.size # [timestamp, value]
  end

  test "should store count" do
    assert_equal 150, @aggregated_metric.count
  end

  test "should store sum" do
    assert_equal 1500, @aggregated_metric.sum
  end

  test "should store avg" do
    assert_equal 10.0, @aggregated_metric.avg
  end

  test "should store min" do
    assert_equal 5.0, @aggregated_metric.min
  end

  test "should store max" do
    assert_equal 20.0, @aggregated_metric.max
  end

  test "should store p50" do
    metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1h",
      bucket_time: Time.current,
      p50: 12.5
    )
    assert_equal 12.5, metric.p50
  end

  test "should store p95" do
    metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1h",
      bucket_time: Time.current,
      p95: 18.0
    )
    assert_equal 18.0, metric.p95
  end

  test "should store p99" do
    metric = @project.aggregated_metrics.create!(
      metric_name: "test",
      bucket_size: "1h",
      bucket_time: Time.current,
      p99: 19.5
    )
    assert_equal 19.5, metric.p99
  end
end
