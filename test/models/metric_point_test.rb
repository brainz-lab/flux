# frozen_string_literal: true

require "test_helper"

class MetricPointTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(platform_project_id: "test_project", name: "Test")
    @metric_point = @project.metric_points.create!(
      metric_name: "api.response_time",
      value: 150.5,
      timestamp: Time.current,
      tags: { region: "us-east" }
    )
  end

  test "should be valid with valid attributes" do
    assert @metric_point.valid?
  end

  test "should require metric_name" do
    point = @project.metric_points.new(value: 100, timestamp: Time.current)
    assert_not point.valid?
    assert_includes point.errors[:metric_name], "can't be blank"
  end

  test "should require timestamp" do
    point = @project.metric_points.new(metric_name: "test", value: 100)
    point.timestamp = nil
    assert_not point.valid?
    assert_includes point.errors[:timestamp], "can't be blank"
  end

  test "should set timestamp if not provided" do
    point = @project.metric_points.create!(metric_name: "test", value: 100)
    assert_not_nil point.timestamp
  end

  test "should belong to project" do
    assert_equal @project, @metric_point.project
  end

  test "should store value" do
    assert_equal 150.5, @metric_point.value
  end

  test "should store tags as JSONB" do
    assert_kind_of Hash, @metric_point.tags
    assert_equal "us-east", @metric_point.tags["region"]
  end

  test "recent scope should order by timestamp descending" do
    old_point = @project.metric_points.create!(
      metric_name: "test",
      value: 100,
      timestamp: 2.hours.ago
    )
    new_point = @project.metric_points.create!(
      metric_name: "test",
      value: 200,
      timestamp: Time.current
    )

    points = @project.metric_points.recent
    assert_equal new_point.id, points.first.id
  end

  test "by_metric scope should filter by metric name" do
    @project.metric_points.create!(metric_name: "other", value: 100, timestamp: Time.current)
    points = @project.metric_points.by_metric("api.response_time")
    assert_equal 1, points.count
    assert_equal "api.response_time", points.first.metric_name
  end

  test "since scope should filter by timestamp" do
    old_point = @project.metric_points.create!(
      metric_name: "test",
      value: 100,
      timestamp: 2.days.ago
    )
    new_point = @project.metric_points.create!(
      metric_name: "test",
      value: 200,
      timestamp: 1.hour.ago
    )

    points = @project.metric_points.since(1.day.ago)
    assert_includes points, new_point
    assert_not_includes points, old_point
  end

  test "until_time scope should filter by timestamp" do
    old_point = @project.metric_points.create!(
      metric_name: "test",
      value: 100,
      timestamp: 2.days.ago
    )
    new_point = @project.metric_points.create!(
      metric_name: "test",
      value: 200,
      timestamp: 1.hour.ago
    )

    points = @project.metric_points.until_time(1.day.ago)
    assert_includes points, old_point
    assert_not_includes points, new_point
  end

  test "with_tag scope should filter by tag" do
    point_with_tag = @project.metric_points.create!(
      metric_name: "test",
      value: 100,
      timestamp: Time.current,
      tags: { region: "us-west" }
    )

    points = @project.metric_points.with_tag("region", "us-west")
    assert_includes points.to_a, point_with_tag
  end

  test "latest_value should return most recent value for metric" do
    @project.metric_points.create!(
      metric_name: "cpu.usage",
      value: 50,
      timestamp: 2.hours.ago
    )
    @project.metric_points.create!(
      metric_name: "cpu.usage",
      value: 75,
      timestamp: Time.current
    )

    latest = MetricPoint.where(project: @project).latest_value("cpu.usage")
    assert_equal 75, latest
  end

  test "stats should return metric statistics" do
    @project.metric_points.create!(metric_name: "test", value: 10, timestamp: Time.current)
    @project.metric_points.create!(metric_name: "test", value: 20, timestamp: Time.current)
    @project.metric_points.create!(metric_name: "test", value: 30, timestamp: Time.current)

    stats = MetricPoint.where(project: @project).stats("test", since: 1.hour.ago)
    assert_equal 3, stats[:count]
    assert_equal 20.0, stats[:avg]
    assert_equal 10, stats[:min]
    assert_equal 30, stats[:max]
    assert_equal 60, stats[:sum]
  end

  test "should store count field" do
    point = @project.metric_points.create!(
      metric_name: "test",
      value: 100,
      timestamp: Time.current,
      count: 5
    )
    assert_equal 5, point.count
  end

  test "should store sample_count field" do
    point = @project.metric_points.create!(
      metric_name: "test",
      value: 100,
      timestamp: Time.current,
      sample_count: 10
    )
    assert_equal 10, point.sample_count
  end

  test "should handle nil tags" do
    point = @project.metric_points.create!(
      metric_name: "test",
      value: 100,
      timestamp: Time.current,
      tags: nil
    )
    assert_nil point.tags
  end
end
