# frozen_string_literal: true

class CleanupOldDataJob < ApplicationJob
  queue_as :default

  def perform
    Project.find_each do |project|
      cleanup_for_project(project)
    end
  rescue => e
    Rails.logger.error("[CleanupOldDataJob] Failed: #{e.message}")
  end

  private

  def cleanup_for_project(project)
    retention_days = project.retention_days || 90
    cutoff = retention_days.days.ago

    # Cleanup old events
    events_deleted = project.events.where("timestamp < ?", cutoff).delete_all
    Rails.logger.info("[CleanupOldDataJob] Deleted #{events_deleted} old events for project #{project.id}")

    # Cleanup old anomalies (keep for 30 days regardless)
    anomalies_cutoff = 30.days.ago
    anomalies_deleted = project.anomalies.where("detected_at < ?", anomalies_cutoff).delete_all
    Rails.logger.info("[CleanupOldDataJob] Deleted #{anomalies_deleted} old anomalies for project #{project.id}")
  rescue => e
    Rails.logger.warn("[CleanupOldDataJob] Cleanup failed for project #{project.id}: #{e.message}")
  end
end
