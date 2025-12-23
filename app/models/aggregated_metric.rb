# frozen_string_literal: true

class AggregatedMetric < ApplicationRecord
  include Timescaledb::Rails::Model

  BUCKET_SIZES = %w[1m 5m 1h 1d].freeze

  belongs_to :project

  validates :metric_name, presence: true
  validates :bucket_size, presence: true, inclusion: { in: BUCKET_SIZES }
  validates :bucket_time, presence: true

  scope :by_metric, ->(name) { where(metric_name: name) }
  scope :by_bucket, ->(size) { where(bucket_size: size) }
  scope :since, ->(time) { where("bucket_time >= ?", time) }
  scope :until_time, ->(time) { where("bucket_time <= ?", time) }

  def self.for_chart(metric_name, bucket_size: "1h", since: 24.hours.ago)
    by_metric(metric_name)
      .by_bucket(bucket_size)
      .since(since)
      .order(:bucket_time)
      .pluck(:bucket_time, :avg)
  end
end
