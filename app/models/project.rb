# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :events, dependent: :delete_all
  has_many :metric_definitions, dependent: :destroy
  has_many :metric_points, dependent: :delete_all
  has_many :aggregated_metrics, dependent: :delete_all
  has_many :flux_dashboards, dependent: :destroy
  has_many :anomalies, dependent: :delete_all

  validates :platform_project_id, presence: true, uniqueness: true
  validates :api_key, uniqueness: true, allow_nil: true
  validates :ingest_key, uniqueness: true, allow_nil: true

  before_validation :generate_keys, on: :create
  before_validation :generate_slug, on: :create

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  # Find or create a project for a Platform project
  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: "production")
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name || "Project #{platform_project_id}"
      p.environment = environment
    end
  end

  def to_param
    slug.presence || id
  end

  # Overview stats for the dashboard
  def overview(since: 24.hours.ago)
    {
      events_total: events.since(since).count,
      events_per_hour: events_per_hour(since: since),
      metrics_total: metric_definitions.count,
      metric_points_total: metric_points.where("timestamp >= ?", since).count,
      anomalies_unacknowledged: anomalies.since(since).unacknowledged.count,
      anomalies_critical: anomalies.since(since).critical.count,
      dashboards_count: flux_dashboards.count,
      top_events: top_events(since: since, limit: 10),
      recent_anomalies: anomalies.since(since).recent.limit(5)
    }
  end

  # Top events by count
  def top_events(since: 24.hours.ago, limit: 10)
    events.since(since)
          .group(:name)
          .count
          .sort_by { |_, v| -v }
          .first(limit)
          .to_h
  end

  # Events per hour rate
  def events_per_hour(since: 24.hours.ago)
    count = events.since(since).count
    hours = [ (Time.current - since) / 1.hour, 1 ].max
    (count / hours).round(1)
  end

  def increment_events_count!(count = 1)
    increment!(:events_count, count)
  end

  def increment_metrics_count!(count = 1)
    increment!(:metrics_count, count)
  end

  private

  def generate_keys
    self.api_key ||= "flx_api_#{SecureRandom.hex(16)}"
    self.ingest_key ||= "flx_ingest_#{SecureRandom.hex(16)}"
  end

  def generate_slug
    return if slug.present?
    return unless name.present?

    base_slug = name.parameterize
    self.slug = base_slug

    counter = 1
    while Project.exists?(slug: slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
