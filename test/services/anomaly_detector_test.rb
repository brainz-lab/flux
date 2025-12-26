# frozen_string_literal: true

require "test_helper"

class AnomalyDetectorTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(
      platform_project_id: "test_project",
      name: "Test Project"
    )
    @detector = AnomalyDetector.new(@project)
  end

  test "detect_for_metric should detect spike" do
    # Create baseline (yesterday)
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 25.hours.ago
    )

    # Create spike (today - 3x baseline)
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 350,
      timestamp: 30.minutes.ago
    )

    anomaly = @detector.detect_for_metric("test.metric", since: 1.hour.ago)

    assert anomaly
    assert_equal "metric", anomaly.source
    assert_equal "test.metric", anomaly.source_name
    assert_equal "spike", anomaly.anomaly_type
    assert anomaly.actual_value > anomaly.expected_value
  end

  test "detect_for_metric should detect drop" do
    # Create baseline (yesterday)
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 25.hours.ago
    )

    # Create drop (today - 0.3x baseline)
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 20,
      timestamp: 30.minutes.ago
    )

    anomaly = @detector.detect_for_metric("test.metric", since: 1.hour.ago)

    assert anomaly
    assert_equal "drop", anomaly.anomaly_type
    assert anomaly.actual_value < anomaly.expected_value
  end

  test "detect_for_metric should return nil with no recent data" do
    anomaly = @detector.detect_for_metric("nonexistent", since: 1.hour.ago)
    assert_nil anomaly
  end

  test "detect_for_metric should return nil with no baseline" do
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 30.minutes.ago
    )

    anomaly = @detector.detect_for_metric("test.metric", since: 1.hour.ago)
    assert_nil anomaly
  end

  test "detect_for_metric should return nil when deviation below threshold" do
    # Create baseline
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 25.hours.ago
    )

    # Create slight increase (within threshold)
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 110,
      timestamp: 30.minutes.ago
    )

    anomaly = @detector.detect_for_metric("test.metric", since: 1.hour.ago)
    assert_nil anomaly
  end

  test "detect_for_metric should use appropriate threshold for error metrics" do
    # Create baseline
    @project.metric_points.create!(
      metric_name: "error.rate",
      value: 10,
      timestamp: 25.hours.ago
    )

    # 60% increase (should trigger for error threshold of 50%)
    @project.metric_points.create!(
      metric_name: "error.rate",
      value: 16,
      timestamp: 30.minutes.ago
    )

    anomaly = @detector.detect_for_metric("error.rate", since: 1.hour.ago)
    assert anomaly
  end

  test "detect_for_metric should calculate severity" do
    # Create baseline
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 25.hours.ago
    )

    # Create critical spike (>200% deviation)
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 400,
      timestamp: 30.minutes.ago
    )

    anomaly = @detector.detect_for_metric("test.metric", since: 1.hour.ago)
    assert anomaly
    assert_equal "critical", anomaly.severity
  end

  test "detect_for_event should detect spike" do
    # Create baseline (yesterday)
    10.times do
      @project.events.create!(
        name: "test.event",
        timestamp: 25.hours.ago
      )
    end

    # Create spike (today - 3x baseline)
    35.times do
      @project.events.create!(
        name: "test.event",
        timestamp: 30.minutes.ago
      )
    end

    anomaly = @detector.detect_for_event("test.event", since: 1.hour.ago)

    assert anomaly
    assert_equal "event", anomaly.source
    assert_equal "test.event", anomaly.source_name
    assert_equal "spike", anomaly.anomaly_type
  end

  test "detect_for_event should detect drop" do
    # Create baseline (yesterday)
    30.times do
      @project.events.create!(
        name: "test.event",
        timestamp: 25.hours.ago
      )
    end

    # Create drop (today - <30% of baseline)
    5.times do
      @project.events.create!(
        name: "test.event",
        timestamp: 30.minutes.ago
      )
    end

    anomaly = @detector.detect_for_event("test.event", since: 1.hour.ago)

    assert anomaly
    assert_equal "drop", anomaly.anomaly_type
  end

  test "detect_for_event should return nil with no recent events" do
    anomaly = @detector.detect_for_event("nonexistent", since: 1.hour.ago)
    assert_nil anomaly
  end

  test "detect_for_event should return nil with no baseline" do
    @project.events.create!(
      name: "test.event",
      timestamp: 30.minutes.ago
    )

    anomaly = @detector.detect_for_event("test.event", since: 1.hour.ago)
    assert_nil anomaly
  end

  test "detect_trend should detect increasing trend" do
    # Create increasing trend over 7 days
    7.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: (i + 1) * 100,
        timestamp: (6 - i).days.ago
      )
    end

    anomaly = @detector.detect_trend("test.metric", periods: 7)

    assert anomaly
    assert_equal "trend", anomaly.anomaly_type
    assert_equal "increasing", anomaly.context["direction"]
  end

  test "detect_trend should detect decreasing trend" do
    # Create decreasing trend over 7 days
    7.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: (7 - i) * 100,
        timestamp: (6 - i).days.ago
      )
    end

    anomaly = @detector.detect_trend("test.metric", periods: 7)

    assert anomaly
    assert_equal "decreasing", anomaly.context["direction"]
  end

  test "detect_trend should return nil with insufficient data" do
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 1.day.ago
    )

    anomaly = @detector.detect_trend("test.metric", periods: 7)
    assert_nil anomaly
  end

  test "detect_trend should return nil with no clear trend" do
    # Create fluctuating data
    [100, 50, 150, 75, 125].each_with_index do |value, i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: value,
        timestamp: (4 - i).days.ago
      )
    end

    anomaly = @detector.detect_trend("test.metric", periods: 5)
    assert_nil anomaly
  end

  test "detect_trend should require at least 20% change" do
    # Create slight increasing trend (less than 20%)
    7.times do |i|
      @project.metric_points.create!(
        metric_name: "test.metric",
        value: 100 + (i * 2),
        timestamp: (6 - i).days.ago
      )
    end

    anomaly = @detector.detect_trend("test.metric", periods: 7)
    assert_nil anomaly
  end

  test "anomaly should include context" do
    # Create spike
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 25.hours.ago
    )
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 350,
      timestamp: 30.minutes.ago
    )

    anomaly = @detector.detect_for_metric("test.metric", since: 1.hour.ago)

    assert anomaly.context["threshold"]
    assert anomaly.context["period"]
    assert anomaly.context["data_points"]
  end
end
