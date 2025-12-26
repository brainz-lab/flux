# frozen_string_literal: true

require "test_helper"

class AnomalyDetectionJobTest < ActiveJob::TestCase
  def setup
    @project = Project.create!(
      platform_project_id: "test_project",
      name: "Test Project"
    )
  end

  test "perform should detect anomaly for specific event" do
    # Create baseline data (yesterday)
    10.times do
      @project.events.create!(
        name: "test.event",
        timestamp: 25.hours.ago
      )
    end

    # Create spike (today - 3x baseline)
    30.times do
      @project.events.create!(
        name: "test.event",
        timestamp: 30.minutes.ago
      )
    end

    event = @project.events.last

    assert_difference "Anomaly.count", 1 do
      AnomalyDetectionJob.perform_now(event.id)
    end

    anomaly = Anomaly.last
    assert_equal "event", anomaly.source
    assert_equal "test.event", anomaly.source_name
    assert_equal "spike", anomaly.anomaly_type
  end

  test "perform should skip if event not found" do
    assert_no_difference "Anomaly.count" do
      AnomalyDetectionJob.perform_now(SecureRandom.uuid)
    end
  end

  test "perform without event_id should detect for all projects" do
    # Create another project
    project2 = Project.create!(
      platform_project_id: "project2",
      name: "Project 2"
    )

    # Create baseline and spike for project1
    10.times do
      @project.events.create!(
        name: "event1",
        timestamp: 25.hours.ago
      )
    end
    30.times do
      @project.events.create!(
        name: "event1",
        timestamp: 30.minutes.ago
      )
    end

    # Create baseline and spike for project2
    5.times do
      project2.events.create!(
        name: "event2",
        timestamp: 25.hours.ago
      )
    end
    20.times do
      project2.events.create!(
        name: "event2",
        timestamp: 30.minutes.ago
      )
    end

    AnomalyDetectionJob.perform_now

    # Should detect anomalies for both projects
    assert @project.anomalies.where(source_name: "event1").exists?
    assert project2.anomalies.where(source_name: "event2").exists?
  end

  test "perform should detect metric anomalies" do
    @project.metric_definitions.create!(
      name: "test.metric",
      metric_type: "gauge"
    )

    # Create baseline (yesterday)
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 100,
      timestamp: 25.hours.ago
    )

    # Create spike (today - 3x baseline)
    @project.metric_points.create!(
      metric_name: "test.metric",
      value: 350,
      timestamp: 30.minutes.ago
    )

    AnomalyDetectionJob.perform_now

    anomaly = @project.anomalies.where(source: "metric").last
    assert anomaly
    assert_equal "test.metric", anomaly.source_name
  end

  test "perform should handle errors gracefully" do
    # Should not raise error even if detection fails
    assert_nothing_raised do
      AnomalyDetectionJob.perform_now
    end
  end

  test "perform should log errors" do
    # Mock logger to verify error logging
    Rails.logger.expects(:error).at_least_once

    # Force an error by creating invalid data
    AnomalyDetectionJob.any_instance.stubs(:detect_for_project).raises(StandardError.new("Test error"))

    AnomalyDetectionJob.perform_now
  end

  test "perform should only process recent events" do
    # Create old events that shouldn't be processed
    @project.events.create!(
      name: "old.event",
      timestamp: 3.days.ago
    )

    # Should not raise error for old events
    assert_nothing_raised do
      AnomalyDetectionJob.perform_now
    end
  end
end
