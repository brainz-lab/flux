# frozen_string_literal: true

class MetricDefinition < ApplicationRecord
  METRIC_TYPES = %w[gauge counter distribution set].freeze

  belongs_to :project

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :metric_type, presence: true, inclusion: { in: METRIC_TYPES }

  scope :by_type, ->(type) { where(metric_type: type) }
  scope :alphabetical, -> { order(:name) }

  def gauge?
    metric_type == "gauge"
  end

  def counter?
    metric_type == "counter"
  end

  def distribution?
    metric_type == "distribution"
  end

  def set?
    metric_type == "set"
  end

  def formatted_unit
    return nil unless unit.present?

    case unit.downcase
    when "ms" then "milliseconds"
    when "s" then "seconds"
    when "bytes", "b" then "bytes"
    when "kb" then "kilobytes"
    when "mb" then "megabytes"
    when "usd", "$" then "USD"
    else unit
    end
  end
end
