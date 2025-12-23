# frozen_string_literal: true

class Anomaly < ApplicationRecord
  SOURCES = %w[metric event].freeze
  ANOMALY_TYPES = %w[spike drop trend seasonality].freeze
  SEVERITIES = %w[info warning critical].freeze

  belongs_to :project

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :source_name, presence: true
  validates :anomaly_type, presence: true, inclusion: { in: ANOMALY_TYPES }
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :detected_at, presence: true

  scope :recent, -> { order(detected_at: :desc) }
  scope :unacknowledged, -> { where(acknowledged: false) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :since, ->(time) { where("detected_at >= ?", time) }
  scope :critical, -> { where(severity: "critical") }
  scope :warnings, -> { where(severity: "warning") }

  def acknowledge!
    update!(acknowledged: true)
  end

  def spike?
    anomaly_type == "spike"
  end

  def drop?
    anomaly_type == "drop"
  end

  def critical?
    severity == "critical"
  end

  def warning?
    severity == "warning"
  end

  def info?
    severity == "info"
  end

  def deviation_description
    return nil unless deviation_percent.present?

    direction = actual_value > expected_value ? "higher" : "lower"
    "#{deviation_percent.round(1)}% #{direction} than expected"
  end
end
