# frozen_string_literal: true

class AnomalyDetectionJob < ApplicationJob
  queue_as :default

  def perform(event_id = nil)
    if event_id
      # Detect anomaly for specific event
      event = Event.find_by(id: event_id)
      return unless event

      detector = AnomalyDetector.new(event.project)
      detector.detect_for_event(event.name)
    else
      # Run detection for all active projects
      Project.find_each do |project|
        detect_for_project(project)
      end
    end
  rescue => e
    Rails.logger.error("[AnomalyDetectionJob] Failed: #{e.message}")
  end

  private

  def detect_for_project(project)
    detector = AnomalyDetector.new(project)

    # Detect event anomalies for top event types
    project.events
      .where("created_at >= ?", 2.hours.ago)
      .group(:name)
      .count
      .keys
      .each do |event_name|
        detector.detect_for_event(event_name, since: 1.hour.ago)
      rescue => e
        Rails.logger.warn("[AnomalyDetectionJob] Event detection failed for #{event_name}: #{e.message}")
      end

    # Detect metric anomalies
    project.metric_definitions.each do |metric|
      detector.detect_for_metric(metric.name, since: 1.hour.ago)
    rescue => e
      Rails.logger.warn("[AnomalyDetectionJob] Metric detection failed for #{metric.name}: #{e.message}")
    end
  end
end
