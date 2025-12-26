# frozen_string_literal: true

require "test_helper"

class CleanupOldDataJobTest < ActiveJob::TestCase
  def setup
    @project = Project.create!(
      platform_project_id: "test_project",
      name: "Test Project",
      retention_days: 90
    )
  end

  test "perform should delete old events" do
    # Create old events beyond retention
    old_events = 3.times.map do
      @project.events.create!(
        name: "old.event",
        timestamp: 100.days.ago
      )
    end

    # Create recent events within retention
    recent_events = 2.times.map do
      @project.events.create!(
        name: "recent.event",
        timestamp: 10.days.ago
      )
    end

    CleanupOldDataJob.perform_now

    # Old events should be deleted
    old_events.each do |event|
      assert_not Event.exists?(event.id)
    end

    # Recent events should remain
    recent_events.each do |event|
      assert Event.exists?(event.id)
    end
  end

  test "perform should delete old anomalies" do
    # Create old anomalies (>30 days)
    old_anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: 40.days.ago
    )

    # Create recent anomaly
    recent_anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: 10.days.ago
    )

    CleanupOldDataJob.perform_now

    # Old anomaly should be deleted
    assert_not Anomaly.exists?(old_anomaly.id)

    # Recent anomaly should remain
    assert Anomaly.exists?(recent_anomaly.id)
  end

  test "perform should use project retention_days" do
    @project.update!(retention_days: 30)

    # Create event at 40 days old (beyond 30 day retention)
    old_event = @project.events.create!(
      name: "test",
      timestamp: 40.days.ago
    )

    CleanupOldDataJob.perform_now

    assert_not Event.exists?(old_event.id)
  end

  test "perform should default to 90 days if retention_days not set" do
    @project.update!(retention_days: nil)

    # Create event at 100 days old
    old_event = @project.events.create!(
      name: "test",
      timestamp: 100.days.ago
    )

    # Create event at 80 days old
    newer_event = @project.events.create!(
      name: "test",
      timestamp: 80.days.ago
    )

    CleanupOldDataJob.perform_now

    # Should use 90 day default
    assert_not Event.exists?(old_event.id)
    assert Event.exists?(newer_event.id)
  end

  test "perform should process all projects" do
    project2 = Project.create!(
      platform_project_id: "project2",
      name: "Project 2",
      retention_days: 90
    )

    # Create old data for both projects
    old_event1 = @project.events.create!(name: "test", timestamp: 100.days.ago)
    old_event2 = project2.events.create!(name: "test", timestamp: 100.days.ago)

    CleanupOldDataJob.perform_now

    # Both should be cleaned
    assert_not Event.exists?(old_event1.id)
    assert_not Event.exists?(old_event2.id)
  end

  test "perform should handle errors gracefully" do
    assert_nothing_raised do
      CleanupOldDataJob.perform_now
    end
  end

  test "perform should log deletions" do
    @project.events.create!(name: "test", timestamp: 100.days.ago)

    Rails.logger.expects(:info).at_least_once

    CleanupOldDataJob.perform_now
  end

  test "perform should continue on project errors" do
    # Create valid project
    project2 = Project.create!(
      platform_project_id: "project2",
      name: "Project 2"
    )
    old_event = project2.events.create!(name: "test", timestamp: 100.days.ago)

    # Mock error for first project
    CleanupOldDataJob.any_instance.stubs(:cleanup_for_project).with(@project).raises(StandardError.new("Test error"))
    CleanupOldDataJob.any_instance.stubs(:cleanup_for_project).with(project2).calls_original

    # Should not raise and should process project2
    assert_nothing_raised do
      CleanupOldDataJob.perform_now
    end
  end
end
