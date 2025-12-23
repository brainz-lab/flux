# frozen_string_literal: true

class Widget < ApplicationRecord
  WIDGET_TYPES = %w[number graph bar pie table heatmap list markdown].freeze

  belongs_to :flux_dashboard, foreign_key: "dashboard_id"

  validates :widget_type, presence: true, inclusion: { in: WIDGET_TYPES }

  scope :by_position, -> { order(Arel.sql("(position->>'y')::int, (position->>'x')::int")) }

  delegate :project, to: :flux_dashboard

  # Query helpers
  def source
    query["source"] || "metrics"
  end

  def metric_name
    query["metric"]
  end

  def event_name
    query["event"]
  end

  def aggregation
    query["aggregation"] || "avg"
  end

  def filters
    query["filters"] || {}
  end

  def group_by
    query["group_by"] || []
  end

  def time_range
    query["time_range"] || "24h"
  end

  # Display helpers
  def color
    display["color"] || "#3B82F6"
  end

  def format
    display["format"] || "number"
  end

  def thresholds
    display["thresholds"] || {}
  end

  def warning_threshold
    thresholds["warning"]
  end

  def critical_threshold
    thresholds["critical"]
  end

  # Position helpers
  def x
    (position["x"] || 0).to_i
  end

  def y
    (position["y"] || 0).to_i
  end

  def width
    (position["w"] || 4).to_i
  end

  def height
    (position["h"] || 2).to_i
  end
end
