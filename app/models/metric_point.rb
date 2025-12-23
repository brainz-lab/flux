# frozen_string_literal: true

class MetricPoint < ApplicationRecord
  include Timescaledb::Rails::Model

  self.primary_key = "id"

  belongs_to :project

  validates :metric_name, presence: true
  validates :timestamp, presence: true

  scope :recent, -> { order(timestamp: :desc) }
  scope :by_metric, ->(name) { where(metric_name: name) }
  scope :since, ->(time) { where("timestamp >= ?", time) }
  scope :until_time, ->(time) { where("timestamp <= ?", time) }
  scope :with_tag, ->(key, value) { where("tags->>? = ?", key, value) }

  before_validation :set_timestamp

  def self.latest_value(metric_name)
    by_metric(metric_name).recent.limit(1).pick(:value)
  end

  def self.time_series(metric_name, since: 24.hours.ago, bucket: "1 hour")
    by_metric(metric_name)
      .since(since)
      .select("time_bucket('#{bucket}', timestamp) AS bucket, AVG(value) as avg_value, COUNT(*) as count")
      .group("bucket")
      .order("bucket")
  end

  def self.stats(metric_name, since: 24.hours.ago)
    points = by_metric(metric_name).since(since)
    {
      count: points.count,
      avg: points.average(:value)&.round(4),
      min: points.minimum(:value),
      max: points.maximum(:value),
      sum: points.sum(:value)
    }
  end

  private

  def set_timestamp
    self.timestamp ||= Time.current
  end
end
