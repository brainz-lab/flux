# frozen_string_literal: true

class AnomalyDetector
  DEFAULT_THRESHOLDS = {
    "default" => 100,      # 100% change (2x)
    "error" => 50,         # 50% change
    "response_time" => 30, # 30% change
    "latency" => 30,
    "failed" => 50
  }.freeze

  attr_reader :project

  def initialize(project)
    @project = project
  end

  def detect_for_metric(metric_name, since: 1.hour.ago)
    recent = get_metric_data(metric_name, since: since)
    return nil if recent.empty?

    # Get baseline (same time yesterday)
    baseline_yesterday = get_metric_data(
      metric_name,
      since: since - 1.day,
      until_time: Time.current - 1.day
    )

    return nil if baseline_yesterday.empty?

    # Calculate expected vs actual
    expected = baseline_yesterday.average(:value)
    actual = recent.average(:value)

    return nil if expected.nil? || actual.nil? || expected.zero?

    # Calculate deviation
    deviation = ((actual - expected) / expected * 100).abs

    # Check threshold
    threshold = threshold_for(metric_name)
    return nil if deviation < threshold

    create_anomaly(
      source: "metric",
      source_name: metric_name,
      anomaly_type: actual > expected ? "spike" : "drop",
      expected_value: expected,
      actual_value: actual,
      deviation_percent: deviation,
      context: {
        threshold: threshold,
        period: since.iso8601,
        data_points: recent.count
      }
    )
  end

  def detect_for_event(event_name, since: 1.hour.ago)
    recent_count = project.events.where(name: event_name).since(since).count
    return nil if recent_count.zero?

    # Get baseline (same time yesterday)
    baseline_count = project.events
      .where(name: event_name)
      .where("timestamp >= ? AND timestamp < ?", since - 1.day, Time.current - 1.day)
      .count

    return nil if baseline_count.zero?

    # Calculate ratio
    ratio = recent_count.to_f / baseline_count

    # Detect spike (3x) or drop (70%)
    if ratio > 3.0
      create_anomaly(
        source: "event",
        source_name: event_name,
        anomaly_type: "spike",
        expected_value: baseline_count,
        actual_value: recent_count,
        deviation_percent: (ratio - 1) * 100,
        context: {
          ratio: ratio.round(2),
          period: since.iso8601
        }
      )
    elsif ratio < 0.3
      create_anomaly(
        source: "event",
        source_name: event_name,
        anomaly_type: "drop",
        expected_value: baseline_count,
        actual_value: recent_count,
        deviation_percent: (1 - ratio) * 100,
        context: {
          ratio: ratio.round(2),
          period: since.iso8601
        }
      )
    end
  end

  def detect_trend(metric_name, periods: 7)
    # Detect gradual changes over multiple periods
    data = []
    periods.times do |i|
      start_time = (i + 1).days.ago.beginning_of_day
      end_time = i.days.ago.beginning_of_day

      avg = MetricPoint
        .where(project: project, metric_name: metric_name)
        .where("timestamp >= ? AND timestamp < ?", start_time, end_time)
        .average(:value)

      data << avg if avg
    end

    return nil if data.size < 3

    # Simple trend detection: check if consistently increasing or decreasing
    increasing = data.each_cons(2).all? { |a, b| b > a }
    decreasing = data.each_cons(2).all? { |a, b| b < a }

    return nil unless increasing || decreasing

    first_value = data.first
    last_value = data.last
    change_percent = ((last_value - first_value) / first_value * 100).abs

    return nil if change_percent < 20 # Require at least 20% change

    create_anomaly(
      source: "metric",
      source_name: metric_name,
      anomaly_type: "trend",
      expected_value: first_value,
      actual_value: last_value,
      deviation_percent: change_percent,
      context: {
        direction: increasing ? "increasing" : "decreasing",
        periods: periods,
        data_points: data
      }
    )
  end

  private

  def get_metric_data(metric_name, since:, until_time: Time.current)
    MetricPoint
      .where(project: project, metric_name: metric_name)
      .where("timestamp >= ? AND timestamp < ?", since, until_time)
  end

  def threshold_for(metric_name)
    # Match against known patterns
    DEFAULT_THRESHOLDS.each do |pattern, threshold|
      return threshold if metric_name.downcase.include?(pattern)
    end

    DEFAULT_THRESHOLDS["default"]
  end

  def create_anomaly(attrs)
    project.anomalies.create!(
      detected_at: Time.current,
      severity: calculate_severity(attrs[:deviation_percent]),
      **attrs
    )
  end

  def calculate_severity(deviation)
    case deviation
    when 0..50 then "info"
    when 50..100 then "warning"
    else "critical"
    end
  end
end
