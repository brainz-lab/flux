# frozen_string_literal: true

class MetricAggregator
  BUCKET_CONFIGS = {
    "1m" => 1.minute,
    "5m" => 5.minutes,
    "1h" => 1.hour,
    "1d" => 1.day
  }.freeze

  attr_reader :project

  def initialize(project)
    @project = project
  end

  # Aggregate a specific metric for a given bucket
  def aggregate(metric_name, bucket_size:, bucket_time:)
    start_time = bucket_time
    end_time = start_time + BUCKET_CONFIGS[bucket_size]

    points = MetricPoint
      .where(project: project, metric_name: metric_name)
      .where("timestamp >= ? AND timestamp < ?", start_time, end_time)

    return if points.empty?

    values = points.pluck(:value).compact

    attrs = {
      project_id: project.id,
      metric_name: metric_name,
      bucket_size: bucket_size,
      bucket_time: bucket_time,
      count: values.size,
      sum: values.sum,
      avg: values.sum.to_f / values.size,
      min: values.min,
      max: values.max
    }

    # Calculate percentiles if enough data
    if values.size >= 10
      sorted = values.sort
      attrs[:p50] = percentile(sorted, 0.5)
      attrs[:p95] = percentile(sorted, 0.95)
      attrs[:p99] = percentile(sorted, 0.99)
    end

    AggregatedMetric.upsert(
      attrs,
      unique_by: [ :project_id, :metric_name, :bucket_size, :bucket_time ]
    )
  end

  # Aggregate all metrics for the past hour
  def aggregate_recent(bucket_size: "1h")
    interval = BUCKET_CONFIGS[bucket_size]
    bucket_time = Time.current.beginning_of_hour - interval

    metric_names = MetricPoint
      .where(project: project)
      .where("timestamp >= ?", bucket_time)
      .distinct.pluck(:metric_name)

    metric_names.each do |name|
      aggregate(name, bucket_size: bucket_size, bucket_time: bucket_time)
    end
  end

  # Backfill aggregations for a metric
  def backfill(metric_name, since:, bucket_size: "1h")
    interval = BUCKET_CONFIGS[bucket_size]
    current_bucket = since.beginning_of_hour

    while current_bucket < Time.current
      aggregate(metric_name, bucket_size: bucket_size, bucket_time: current_bucket)
      current_bucket += interval
    end
  end

  private

  def percentile(sorted_values, p)
    return nil if sorted_values.empty?

    k = (p * (sorted_values.size - 1)).floor
    f = (p * (sorted_values.size - 1)) % 1

    if f.zero?
      sorted_values[k]
    else
      sorted_values[k] * (1 - f) + sorted_values[k + 1] * f
    end
  end
end
