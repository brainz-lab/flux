# frozen_string_literal: true

class Event < ApplicationRecord
  include Timescaledb::Rails::Model

  self.primary_key = "id"

  belongs_to :project, counter_cache: :events_count

  validates :name, presence: true
  validates :timestamp, presence: true

  scope :recent, -> { order(timestamp: :desc) }
  scope :by_name, ->(name) { where(name: name) }
  scope :since, ->(time) { where("timestamp >= ?", time) }
  scope :until_time, ->(time) { where("timestamp <= ?", time) }
  scope :with_tag, ->(key, value) { where("tags->>? = ?", key, value) }
  scope :with_property, ->(key, value) { where("properties->>? = ?", key, value) }

  before_validation :set_timestamp

  def self.count_by_name(since: 24.hours.ago)
    since(since)
      .group(:name)
      .count
      .sort_by { |_, count| -count }
      .to_h
  end

  def self.count_by_hour(since: 24.hours.ago)
    since(since)
      .group_by_hour(:timestamp)
      .count
  end

  def self.stats(since: 24.hours.ago)
    events = since(since)
    {
      total: events.count,
      unique_names: events.distinct.count(:name),
      with_value: events.where.not(value: nil).count,
      avg_value: events.where.not(value: nil).average(:value)&.round(2)
    }
  end

  private

  def set_timestamp
    self.timestamp ||= Time.current
  end
end
