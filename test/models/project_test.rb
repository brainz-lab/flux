# frozen_string_literal: true

require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(
      platform_project_id: "platform_123",
      name: "Test Project",
      environment: "production"
    )
  end

  test "should be valid with valid attributes" do
    assert @project.valid?
  end

  test "should require platform_project_id" do
    project = Project.new(name: "Test")
    assert_not project.valid?
    assert_includes project.errors[:platform_project_id], "can't be blank"
  end

  test "should have unique platform_project_id" do
    duplicate = Project.new(platform_project_id: @project.platform_project_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:platform_project_id], "has already been taken"
  end

  test "should have unique api_key" do
    project1 = Project.create!(platform_project_id: "p1", name: "P1")
    project2 = Project.new(platform_project_id: "p2", api_key: project1.api_key)
    assert_not project2.valid?
    assert_includes project2.errors[:api_key], "has already been taken"
  end

  test "should have unique ingest_key" do
    project1 = Project.create!(platform_project_id: "p1", name: "P1")
    project2 = Project.new(platform_project_id: "p2", ingest_key: project1.ingest_key)
    assert_not project2.valid?
    assert_includes project2.errors[:ingest_key], "has already been taken"
  end

  test "should generate api_key on create" do
    project = Project.create!(platform_project_id: "new_project")
    assert_not_nil project.api_key
    assert project.api_key.start_with?("flx_api_")
  end

  test "should generate ingest_key on create" do
    project = Project.create!(platform_project_id: "new_project")
    assert_not_nil project.ingest_key
    assert project.ingest_key.start_with?("flx_ingest_")
  end

  test "should generate slug from name on create" do
    project = Project.create!(platform_project_id: "p1", name: "My Test Project")
    assert_equal "my-test-project", project.slug
  end

  test "should generate unique slug when duplicate exists" do
    Project.create!(platform_project_id: "p1", name: "Test")
    project2 = Project.create!(platform_project_id: "p2", name: "Test")
    assert_equal "test-1", project2.slug
  end

  test "should use slug in to_param" do
    assert_equal @project.slug, @project.to_param
  end

  test "should have active scope" do
    active_project = Project.create!(platform_project_id: "active", api_key: "key")
    inactive_project = Project.new(platform_project_id: "inactive")
    inactive_project.save(validate: false)

    assert_includes Project.active, active_project
  end

  test "find_or_create_for_platform! should find existing project" do
    project = Project.find_or_create_for_platform!(platform_project_id: @project.platform_project_id)
    assert_equal @project.id, project.id
  end

  test "find_or_create_for_platform! should create new project" do
    project = Project.find_or_create_for_platform!(
      platform_project_id: "new_platform_id",
      name: "New Project",
      environment: "staging"
    )
    assert_not_nil project.id
    assert_equal "New Project", project.name
    assert_equal "staging", project.environment
  end

  test "should have many events" do
    assert_respond_to @project, :events
  end

  test "should have many metric_definitions" do
    assert_respond_to @project, :metric_definitions
  end

  test "should have many metric_points" do
    assert_respond_to @project, :metric_points
  end

  test "should have many flux_dashboards" do
    assert_respond_to @project, :flux_dashboards
  end

  test "should have many anomalies" do
    assert_respond_to @project, :anomalies
  end

  test "increment_events_count! should increment counter" do
    initial_count = @project.events_count || 0
    @project.increment_events_count!(5)
    assert_equal initial_count + 5, @project.reload.events_count
  end

  test "increment_metrics_count! should increment counter" do
    initial_count = @project.metrics_count || 0
    @project.increment_metrics_count!(3)
    assert_equal initial_count + 3, @project.reload.metrics_count
  end

  test "overview should return project statistics" do
    overview = @project.overview
    assert_kind_of Hash, overview
    assert_includes overview.keys, :events_total
    assert_includes overview.keys, :metrics_total
    assert_includes overview.keys, :anomalies_unacknowledged
  end

  test "top_events should return event counts sorted by frequency" do
    5.times { @project.events.create!(name: "popular_event", timestamp: Time.current) }
    2.times { @project.events.create!(name: "rare_event", timestamp: Time.current) }

    top = @project.top_events(since: 1.hour.ago)
    assert_equal 2, top.size
    assert_equal 5, top["popular_event"]
    assert_equal 2, top["rare_event"]
  end

  test "events_per_hour should calculate rate" do
    @project.events.create!(name: "test", timestamp: Time.current)
    rate = @project.events_per_hour(since: 1.hour.ago)
    assert_kind_of Float, rate
    assert rate >= 0
  end
end
