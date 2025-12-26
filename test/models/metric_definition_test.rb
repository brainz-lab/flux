# frozen_string_literal: true

require "test_helper"

class MetricDefinitionTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(platform_project_id: "test_project", name: "Test")
    @metric = @project.metric_definitions.create!(
      name: "api.requests",
      metric_type: "counter",
      description: "API request count",
      unit: "requests"
    )
  end

  test "should be valid with valid attributes" do
    assert @metric.valid?
  end

  test "should require name" do
    metric = @project.metric_definitions.new(metric_type: "counter")
    assert_not metric.valid?
    assert_includes metric.errors[:name], "can't be blank"
  end

  test "should require metric_type" do
    metric = @project.metric_definitions.new(name: "test")
    assert_not metric.valid?
    assert_includes metric.errors[:metric_type], "can't be blank"
  end

  test "should validate metric_type is in allowed types" do
    metric = @project.metric_definitions.new(name: "test", metric_type: "invalid")
    assert_not metric.valid?
    assert_includes metric.errors[:metric_type], "is not included in the list"
  end

  test "should allow gauge metric type" do
    metric = @project.metric_definitions.create!(name: "test.gauge", metric_type: "gauge")
    assert metric.valid?
    assert metric.gauge?
  end

  test "should allow counter metric type" do
    metric = @project.metric_definitions.create!(name: "test.counter", metric_type: "counter")
    assert metric.valid?
    assert metric.counter?
  end

  test "should allow distribution metric type" do
    metric = @project.metric_definitions.create!(name: "test.distribution", metric_type: "distribution")
    assert metric.valid?
    assert metric.distribution?
  end

  test "should allow set metric type" do
    metric = @project.metric_definitions.create!(name: "test.set", metric_type: "set")
    assert metric.valid?
    assert metric.set?
  end

  test "should have unique name per project" do
    duplicate = @project.metric_definitions.new(
      name: @metric.name,
      metric_type: "gauge"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name in different projects" do
    other_project = Project.create!(platform_project_id: "other_project", name: "Other")
    metric = other_project.metric_definitions.create!(
      name: @metric.name,
      metric_type: "gauge"
    )
    assert metric.valid?
  end

  test "should belong to project" do
    assert_equal @project, @metric.project
  end

  test "by_type scope should filter by metric type" do
    @project.metric_definitions.create!(name: "gauge_metric", metric_type: "gauge")
    @project.metric_definitions.create!(name: "counter_metric", metric_type: "counter")

    gauges = @project.metric_definitions.by_type("gauge")
    assert_equal 1, gauges.count
    assert_equal "gauge_metric", gauges.first.name
  end

  test "alphabetical scope should order by name" do
    @project.metric_definitions.create!(name: "zebra", metric_type: "gauge")
    @project.metric_definitions.create!(name: "alpha", metric_type: "counter")

    metrics = @project.metric_definitions.alphabetical
    assert_equal "alpha", metrics.first.name
  end

  test "gauge? should return true for gauge type" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "gauge")
    assert metric.gauge?
    assert_not metric.counter?
    assert_not metric.distribution?
    assert_not metric.set?
  end

  test "counter? should return true for counter type" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "counter")
    assert metric.counter?
    assert_not metric.gauge?
  end

  test "distribution? should return true for distribution type" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "distribution")
    assert metric.distribution?
    assert_not metric.gauge?
  end

  test "set? should return true for set type" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "set")
    assert metric.set?
    assert_not metric.gauge?
  end

  test "formatted_unit should format milliseconds" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "gauge", unit: "ms")
    assert_equal "milliseconds", metric.formatted_unit
  end

  test "formatted_unit should format seconds" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "gauge", unit: "s")
    assert_equal "seconds", metric.formatted_unit
  end

  test "formatted_unit should format bytes" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "gauge", unit: "bytes")
    assert_equal "bytes", metric.formatted_unit
  end

  test "formatted_unit should format USD" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "gauge", unit: "usd")
    assert_equal "USD", metric.formatted_unit
  end

  test "formatted_unit should return original unit for unknown types" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "gauge", unit: "custom")
    assert_equal "custom", metric.formatted_unit
  end

  test "formatted_unit should return nil when no unit" do
    metric = @project.metric_definitions.create!(name: "test", metric_type: "gauge")
    assert_nil metric.formatted_unit
  end

  test "should store description" do
    assert_equal "API request count", @metric.description
  end

  test "should store unit" do
    assert_equal "requests", @metric.unit
  end
end
