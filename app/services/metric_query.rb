# frozen_string_literal: true

class MetricQuery
  AGGREGATIONS = %w[avg sum min max count p50 p95 p99 last].freeze

  attr_reader :project, :metric_name, :params

  def initialize(project, metric_name, params = {})
    @project = project
    @metric_name = metric_name
    @params = params.with_indifferent_access
  end

  def execute
    {
      data: time_series,
      aggregation: aggregation,
      stats: stats
    }
  end

  def latest
    base_scope.order(timestamp: :desc).limit(1).pick(:value)
  end

  def time_series
    scope = base_scope
    scope = apply_filters(scope)

    bucket = params[:bucket] || auto_bucket
    agg = aggregation

    results = scope
      .select("time_bucket('#{bucket}', timestamp) AS bucket, #{aggregation_sql(agg)}")
      .group("bucket")
      .order("bucket")

    results.map { |r| { time: r.bucket, value: r.agg_value&.round(4) } }
  end

  def stats
    scope = base_scope
    scope = apply_filters(scope)

    {
      count: scope.count,
      avg: scope.average(:value)&.round(4),
      sum: scope.sum(:value)&.round(4),
      min: scope.minimum(:value)&.round(4),
      max: scope.maximum(:value)&.round(4)
    }
  end

  def group_by(field)
    scope = base_scope
    scope = apply_filters(scope)

    scope
      .group("tags->>'#{field}'")
      .select("tags->>'#{field}' AS group_key, AVG(value) as avg_value, COUNT(*) as count")
      .map { |r| { key: r.group_key, avg: r.avg_value&.round(4), count: r.count } }
  end

  private

  def base_scope
    MetricPoint.where(project: project, metric_name: metric_name)
  end

  def apply_filters(scope)
    # Time filters
    scope = scope.since(parse_time(params[:since])) if params[:since].present?
    scope = scope.until_time(Time.parse(params[:until])) if params[:until].present?

    # Default to last 24 hours
    scope = scope.since(24.hours.ago) unless params[:since].present? || params[:until].present?

    # Tag filters
    if params[:tags].present?
      params[:tags].each do |key, value|
        scope = scope.where("tags->>? = ?", key, value.to_s)
      end
    end

    scope
  end

  def aggregation
    agg = params[:aggregation] || "avg"
    AGGREGATIONS.include?(agg) ? agg : "avg"
  end

  def aggregation_sql(agg)
    case agg
    when "avg" then "AVG(value) as agg_value"
    when "sum" then "SUM(value) as agg_value"
    when "min" then "MIN(value) as agg_value"
    when "max" then "MAX(value) as agg_value"
    when "count" then "COUNT(*) as agg_value"
    when "p50" then "percentile_cont(0.5) WITHIN GROUP (ORDER BY value) as agg_value"
    when "p95" then "percentile_cont(0.95) WITHIN GROUP (ORDER BY value) as agg_value"
    when "p99" then "percentile_cont(0.99) WITHIN GROUP (ORDER BY value) as agg_value"
    when "last" then "LAST(value, timestamp) as agg_value"
    else "AVG(value) as agg_value"
    end
  end

  def auto_bucket
    since = params[:since] ? parse_time(params[:since]) : 24.hours.ago
    duration = Time.current - since

    case duration
    when 0..1.hour then "1 minute"
    when 1.hour..6.hours then "5 minutes"
    when 6.hours..24.hours then "15 minutes"
    when 24.hours..7.days then "1 hour"
    when 7.days..30.days then "6 hours"
    else "1 day"
    end
  end

  def parse_time(value)
    case value
    when /^(\d+)m$/ then $1.to_i.minutes.ago
    when /^(\d+)h$/ then $1.to_i.hours.ago
    when /^(\d+)d$/ then $1.to_i.days.ago
    when /^(\d+)w$/ then $1.to_i.weeks.ago
    else
      begin
        Time.parse(value)
      rescue
        24.hours.ago
      end
    end
  end
end
