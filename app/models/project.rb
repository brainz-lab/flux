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

  scope :active, -> { where.not(api_key: nil) }

  # Find or create a project for a Platform project
  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: "production")
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name || "Project #{platform_project_id}"
      p.environment = environment
    end
  end

  def to_param
    id
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
end
