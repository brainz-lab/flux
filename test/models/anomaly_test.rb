# frozen_string_literal: true

require "test_helper"

class AnomalyTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(platform_project_id: "test_project", name: "Test")
    @anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "api.requests",
      anomaly_type: "spike",
      severity: "critical",
      detected_at: Time.current,
      expected_value: 100,
      actual_value: 350,
      deviation_percent: 250
    )
  end

  test "should be valid with valid attributes" do
    assert @anomaly.valid?
  end

  test "should require source" do
    anomaly = @project.anomalies.new(
      source_name: "test",
      anomaly_type: "spike",
      severity: "critical",
      detected_at: Time.current
    )
    assert_not anomaly.valid?
    assert_includes anomaly.errors[:source], "can't be blank"
  end

  test "should validate source is in allowed values" do
    anomaly = @project.anomalies.new(
      source: "invalid",
      source_name: "test",
      anomaly_type: "spike",
      severity: "critical",
      detected_at: Time.current
    )
    assert_not anomaly.valid?
    assert_includes anomaly.errors[:source], "is not included in the list"
  end

  test "should allow metric source" do
    anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current
    )
    assert anomaly.valid?
  end

  test "should allow event source" do
    anomaly = @project.anomalies.create!(
      source: "event",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current
    )
    assert anomaly.valid?
  end

  test "should require source_name" do
    anomaly = @project.anomalies.new(
      source: "metric",
      anomaly_type: "spike",
      severity: "critical",
      detected_at: Time.current
    )
    assert_not anomaly.valid?
    assert_includes anomaly.errors[:source_name], "can't be blank"
  end

  test "should require anomaly_type" do
    anomaly = @project.anomalies.new(
      source: "metric",
      source_name: "test",
      severity: "critical",
      detected_at: Time.current
    )
    assert_not anomaly.valid?
    assert_includes anomaly.errors[:anomaly_type], "can't be blank"
  end

  test "should validate anomaly_type is in allowed values" do
    anomaly = @project.anomalies.new(
      source: "metric",
      source_name: "test",
      anomaly_type: "invalid",
      severity: "critical",
      detected_at: Time.current
    )
    assert_not anomaly.valid?
    assert_includes anomaly.errors[:anomaly_type], "is not included in the list"
  end

  test "should require severity" do
    anomaly = @project.anomalies.new(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      detected_at: Time.current
    )
    assert_not anomaly.valid?
    assert_includes anomaly.errors[:severity], "can't be blank"
  end

  test "should validate severity is in allowed values" do
    anomaly = @project.anomalies.new(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "invalid",
      detected_at: Time.current
    )
    assert_not anomaly.valid?
    assert_includes anomaly.errors[:severity], "is not included in the list"
  end

  test "should require detected_at" do
    anomaly = @project.anomalies.new(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "critical"
    )
    assert_not anomaly.valid?
    assert_includes anomaly.errors[:detected_at], "can't be blank"
  end

  test "should belong to project" do
    assert_equal @project, @anomaly.project
  end

  test "recent scope should order by detected_at descending" do
    old_anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: 2.hours.ago
    )
    new_anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current
    )

    anomalies = @project.anomalies.recent
    assert_equal new_anomaly.id, anomalies.first.id
  end

  test "unacknowledged scope should filter unacknowledged anomalies" do
    acknowledged = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current,
      acknowledged: true
    )

    anomalies = @project.anomalies.unacknowledged
    assert_not_includes anomalies, acknowledged
    assert_includes anomalies, @anomaly
  end

  test "by_severity scope should filter by severity" do
    warning = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current
    )

    anomalies = @project.anomalies.by_severity("warning")
    assert_includes anomalies, warning
    assert_not_includes anomalies, @anomaly
  end

  test "since scope should filter by detected_at" do
    old = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: 2.days.ago
    )

    anomalies = @project.anomalies.since(1.day.ago)
    assert_includes anomalies, @anomaly
    assert_not_includes anomalies, old
  end

  test "critical scope should filter critical anomalies" do
    warning = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current
    )

    anomalies = @project.anomalies.critical
    assert_includes anomalies, @anomaly
    assert_not_includes anomalies, warning
  end

  test "warnings scope should filter warning anomalies" do
    warning = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current
    )

    anomalies = @project.anomalies.warnings
    assert_includes anomalies, warning
    assert_not_includes anomalies, @anomaly
  end

  test "acknowledge! should mark as acknowledged" do
    assert_not @anomaly.acknowledged
    @anomaly.acknowledge!
    assert @anomaly.acknowledged
  end

  test "spike? should return true for spike type" do
    assert @anomaly.spike?
    assert_not @anomaly.drop?
  end

  test "drop? should return true for drop type" do
    anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "drop",
      severity: "warning",
      detected_at: Time.current
    )
    assert anomaly.drop?
    assert_not anomaly.spike?
  end

  test "critical? should return true for critical severity" do
    assert @anomaly.critical?
    assert_not @anomaly.warning?
    assert_not @anomaly.info?
  end

  test "warning? should return true for warning severity" do
    anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current
    )
    assert anomaly.warning?
    assert_not anomaly.critical?
  end

  test "info? should return true for info severity" do
    anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "info",
      detected_at: Time.current
    )
    assert anomaly.info?
    assert_not anomaly.critical?
  end

  test "deviation_description should describe positive deviation" do
    description = @anomaly.deviation_description
    assert_includes description, "250.0%"
    assert_includes description, "higher"
  end

  test "deviation_description should describe negative deviation" do
    anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "drop",
      severity: "warning",
      detected_at: Time.current,
      expected_value: 100,
      actual_value: 50,
      deviation_percent: 50
    )
    description = anomaly.deviation_description
    assert_includes description, "lower"
  end

  test "deviation_description should return nil without deviation_percent" do
    anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current
    )
    assert_nil anomaly.deviation_description
  end

  test "should store context as JSONB" do
    anomaly = @project.anomalies.create!(
      source: "metric",
      source_name: "test",
      anomaly_type: "spike",
      severity: "warning",
      detected_at: Time.current,
      context: { threshold: 100, reason: "test" }
    )
    assert_kind_of Hash, anomaly.context
    assert_equal 100, anomaly.context["threshold"]
  end
end
