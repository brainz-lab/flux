# frozen_string_literal: true

require "test_helper"

class WidgetTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(platform_project_id: "test_project", name: "Test")
    @dashboard = @project.flux_dashboards.create!(name: "Dashboard")
    @widget = @dashboard.widgets.create!(
      name: "API Requests",
      widget_type: "number",
      query: { source: "metrics", metric: "api.requests", aggregation: "sum" },
      display: { color: "#FF0000", format: "number" },
      position: { x: 0, y: 0, w: 4, h: 2 }
    )
  end

  test "should be valid with valid attributes" do
    assert @widget.valid?
  end

  test "should require widget_type" do
    widget = @dashboard.widgets.new(
      query: {},
      display: {},
      position: {}
    )
    assert_not widget.valid?
    assert_includes widget.errors[:widget_type], "can't be blank"
  end

  test "should validate widget_type is in allowed types" do
    widget = @dashboard.widgets.new(widget_type: "invalid")
    assert_not widget.valid?
    assert_includes widget.errors[:widget_type], "is not included in the list"
  end

  test "should allow number widget type" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      query: {},
      display: {},
      position: {}
    )
    assert widget.valid?
  end

  test "should allow graph widget type" do
    widget = @dashboard.widgets.create!(
      widget_type: "graph",
      query: {},
      display: {},
      position: {}
    )
    assert widget.valid?
  end

  test "should allow bar widget type" do
    widget = @dashboard.widgets.create!(
      widget_type: "bar",
      query: {},
      display: {},
      position: {}
    )
    assert widget.valid?
  end

  test "should allow pie widget type" do
    widget = @dashboard.widgets.create!(
      widget_type: "pie",
      query: {},
      display: {},
      position: {}
    )
    assert widget.valid?
  end

  test "should allow table widget type" do
    widget = @dashboard.widgets.create!(
      widget_type: "table",
      query: {},
      display: {},
      position: {}
    )
    assert widget.valid?
  end

  test "should allow heatmap widget type" do
    widget = @dashboard.widgets.create!(
      widget_type: "heatmap",
      query: {},
      display: {},
      position: {}
    )
    assert widget.valid?
  end

  test "should belong to flux_dashboard" do
    assert_equal @dashboard, @widget.flux_dashboard
  end

  test "should delegate project to flux_dashboard" do
    assert_equal @project, @widget.project
  end

  test "by_position scope should order by position" do
    widget1 = @dashboard.widgets.create!(
      widget_type: "number",
      position: { x: 0, y: 1 }
    )
    widget2 = @dashboard.widgets.create!(
      widget_type: "number",
      position: { x: 0, y: 0 }
    )

    widgets = @dashboard.widgets.by_position
    assert_equal widget2.id, widgets.first.id
  end

  test "source should return query source" do
    assert_equal "metrics", @widget.source
  end

  test "source should default to metrics" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      query: {}
    )
    assert_equal "metrics", widget.source
  end

  test "metric_name should return query metric" do
    assert_equal "api.requests", @widget.metric_name
  end

  test "event_name should return query event" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      query: { event: "user.signup" }
    )
    assert_equal "user.signup", widget.event_name
  end

  test "aggregation should return query aggregation" do
    assert_equal "sum", @widget.aggregation
  end

  test "aggregation should default to avg" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      query: {}
    )
    assert_equal "avg", widget.aggregation
  end

  test "filters should return query filters" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      query: { filters: { environment: "production" } }
    )
    assert_equal({ "environment" => "production" }, widget.filters)
  end

  test "filters should default to empty hash" do
    assert_equal({}, @widget.filters)
  end

  test "group_by should return query group_by" do
    widget = @dashboard.widgets.create!(
      widget_type: "bar",
      query: { group_by: ["region", "environment"] }
    )
    assert_equal ["region", "environment"], widget.group_by
  end

  test "group_by should default to empty array" do
    assert_equal [], @widget.group_by
  end

  test "time_range should return query time_range" do
    widget = @dashboard.widgets.create!(
      widget_type: "graph",
      query: { time_range: "7d" }
    )
    assert_equal "7d", widget.time_range
  end

  test "time_range should default to 24h" do
    widget = @dashboard.widgets.create!(
      widget_type: "graph",
      query: {}
    )
    assert_equal "24h", widget.time_range
  end

  test "color should return display color" do
    assert_equal "#FF0000", @widget.color
  end

  test "color should default to blue" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      display: {}
    )
    assert_equal "#3B82F6", widget.color
  end

  test "format should return display format" do
    assert_equal "number", @widget.format
  end

  test "format should default to number" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      display: {}
    )
    assert_equal "number", widget.format
  end

  test "thresholds should return display thresholds" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      display: { thresholds: { warning: 100, critical: 200 } }
    )
    assert_equal({ "warning" => 100, "critical" => 200 }, widget.thresholds)
  end

  test "thresholds should default to empty hash" do
    assert_equal({}, @widget.thresholds)
  end

  test "warning_threshold should return threshold value" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      display: { thresholds: { warning: 100 } }
    )
    assert_equal 100, widget.warning_threshold
  end

  test "critical_threshold should return threshold value" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      display: { thresholds: { critical: 200 } }
    )
    assert_equal 200, widget.critical_threshold
  end

  test "x should return position x coordinate" do
    assert_equal 0, @widget.x
  end

  test "x should default to 0" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      position: {}
    )
    assert_equal 0, widget.x
  end

  test "y should return position y coordinate" do
    assert_equal 0, @widget.y
  end

  test "width should return position width" do
    assert_equal 4, @widget.width
  end

  test "width should default to 4" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      position: {}
    )
    assert_equal 4, widget.width
  end

  test "height should return position height" do
    assert_equal 2, @widget.height
  end

  test "height should default to 2" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      position: {}
    )
    assert_equal 2, widget.height
  end

  test "should store query as JSONB" do
    assert_kind_of Hash, @widget.query
  end

  test "should store display as JSONB" do
    assert_kind_of Hash, @widget.display
  end

  test "should store position as JSONB" do
    assert_kind_of Hash, @widget.position
  end
end
