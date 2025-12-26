# frozen_string_literal: true

require "test_helper"

class MetricAggregatorTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(
      platform_project_id: "test_project",
      name: "Test Project"
    )
    @aggregator = MetricAggregator.new(@project)
  end

  test "aggregate should create aggregated metric" do
    bucket_time = 1.hour.ago.beginning_of_hour

    # Create metric points within the bucket
    5.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: (i + 1) * 10,
        timestamp: bucket_time + (i * 10).minutes
      )
    end

    assert_difference "AggregatedMetric.count", 1 do
      @aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)
    end

    aggregated = AggregatedMetric.last
    assert_equal "test.metric", aggregated.metric_name
    assert_equal "1h", aggregated.bucket_size
    assert_equal bucket_time, aggregated.bucket_time
    assert_equal 5, aggregated.count
  end

  test "aggregate should calculate statistics correctly" do
    bucket_time = 1.hour.ago.beginning_of_hour
    values = [10, 20, 30, 40, 50]

    values.each do |value|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: value,
        timestamp: bucket_time + 10.minutes
      )
    end

    @aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

    aggregated = AggregatedMetric.last
    assert_equal 5, aggregated.count
    assert_equal 150, aggregated.sum
    assert_equal 30.0, aggregated.avg
    assert_equal 10, aggregated.min
    assert_equal 50, aggregated.max
  end

  test "aggregate should calculate percentiles with enough data" do
    bucket_time = 1.hour.ago.beginning_of_hour

    # Create 20 data points for percentile calculation
    20.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: i + 1,
        timestamp: bucket_time + (i * 2).minutes
      )
    end

    @aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

    aggregated = AggregatedMetric.last
    assert_not_nil aggregated.p50
    assert_not_nil aggregated.p95
    assert_not_nil aggregated.p99
  end

  test "aggregate should skip percentiles with insufficient data" do
    bucket_time = 1.hour.ago.beginning_of_hour

    # Create only 5 data points (less than 10)
    5.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: i + 1,
        timestamp: bucket_time + (i * 10).minutes
      )
    end

    @aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

    aggregated = AggregatedMetric.last
    assert_nil aggregated.p50
    assert_nil aggregated.p95
    assert_nil aggregated.p99
  end

  test "aggregate should return nil with no data" do
    bucket_time = 1.hour.ago.beginning_of_hour

    result = @aggregator.aggregate("nonexistent", bucket_size: "1h", bucket_time: bucket_time)

    assert_nil result
    assert_equal 0, AggregatedMetric.count
  end

  test "aggregate should upsert existing aggregation" do
    bucket_time = 1.hour.ago.beginning_of_hour

    # Create initial aggregation
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: bucket_time + 10.minutes
    )
    @aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

    # Add more data and re-aggregate
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 200,
      timestamp: bucket_time + 20.minutes
    )

    assert_no_difference "AggregatedMetric.count" do
      @aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)
    end

    # Should update the existing record
    aggregated = AggregatedMetric.last
    assert_equal 2, aggregated.count
  end

  test "aggregate should handle different bucket sizes" do
    bucket_time = 1.day.ago.beginning_of_day

    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: bucket_time + 1.hour
    )

    @aggregator.aggregate("test.metric", bucket_size: "1d", bucket_time: bucket_time)

    aggregated = AggregatedMetric.last
    assert_equal "1d", aggregated.bucket_size
  end

  test "aggregate_recent should process all metrics" do
    bucket_time = 2.hours.ago.beginning_of_hour

    # Create points for multiple metrics
    @project.metric_points.create!(
      metric_name: "metric1",
      value: 100,
      timestamp: bucket_time + 10.minutes
    )
    @project.metric_points.create!(
      metric_name: "metric2",
      value: 200,
      timestamp: bucket_time + 20.minutes
    )

    @aggregator.aggregate_recent(bucket_size: "1h")

    # Should create aggregations for both metrics
    assert @project.aggregated_metrics.exists?(metric_name: "metric1")
    assert @project.aggregated_metrics.exists?(metric_name: "metric2")
  end

  test "backfill should create aggregations for time range" do
    start_time = 3.hours.ago.beginning_of_hour

    # Create data across multiple hours
    3.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: 100,
        timestamp: start_time + (i * 1.hour) + 10.minutes
      )
    end

    @aggregator.backfill("test.metric", since: start_time, bucket_size: "1h")

    # Should create aggregations for each hour
    assert @project.aggregated_metrics.where(metric_name: "test.metric").count >= 3
  end

  test "backfill should handle 5 minute buckets" do
    start_time = 30.minutes.ago.beginning_of_hour

    # Create data across 3 x 5-minute periods
    3.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: 100,
        timestamp: start_time + (i * 5.minutes) + 1.minute
      )
    end

    @aggregator.backfill("test.metric", since: start_time, bucket_size: "5m")

    assert @project.aggregated_metrics.where(
      metric_name: "test.metric",
      bucket_size: "5m"
    ).count >= 3
  end

  test "percentile calculation should work correctly" do
    sorted = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    # Use reflection to test private method
    p50 = @aggregator.send(:percentile, sorted, 0.5)
    assert_in_delta 5.5, p50, 0.1

    p95 = @aggregator.send(:percentile, sorted, 0.95)
    assert p95 > 9
  end

  test "percentile should handle empty array" do
    result = @aggregator.send(:percentile, [], 0.5)
    assert_nil result
  end

  test "aggregate should skip nil values" do
    bucket_time = 1.hour.ago.beginning_of_hour

    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: bucket_time + 10.minutes
    )
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: nil,
      timestamp: bucket_time + 20.minutes
    )
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 200,
      timestamp: bucket_time + 30.minutes
    )

    @aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

    aggregated = AggregatedMetric.last
    assert_equal 2, aggregated.count # Should only count non-nil values
    assert_equal 150.0, aggregated.avg
  end
end
