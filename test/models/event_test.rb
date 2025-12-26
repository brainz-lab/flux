# frozen_string_literal: true

require "test_helper"

class EventTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(platform_project_id: "test_project", name: "Test")
    @event = @project.events.create!(
      name: "user.signup",
      timestamp: Time.current,
      properties: { plan: "pro" },
      tags: { environment: "production" }
    )
  end

  test "should be valid with valid attributes" do
    assert @event.valid?
  end

  test "should require name" do
    event = @project.events.new(timestamp: Time.current)
    assert_not event.valid?
    assert_includes event.errors[:name], "can't be blank"
  end

  test "should require timestamp" do
    event = @project.events.new(name: "test")
    event.timestamp = nil
    assert_not event.valid?
    assert_includes event.errors[:timestamp], "can't be blank"
  end

  test "should set timestamp if not provided" do
    event = @project.events.create!(name: "test")
    assert_not_nil event.timestamp
  end

  test "should belong to project" do
    assert_equal @project, @event.project
  end

  test "should increment project events_count" do
    initial_count = @project.reload.events_count
    @project.events.create!(name: "test", timestamp: Time.current)
    assert_equal initial_count + 1, @project.reload.events_count
  end

  test "should store properties as JSONB" do
    assert_kind_of Hash, @event.properties
    assert_equal "pro", @event.properties["plan"]
  end

  test "should store tags as JSONB" do
    assert_kind_of Hash, @event.tags
    assert_equal "production", @event.tags["environment"]
  end

  test "recent scope should order by timestamp descending" do
    old_event = @project.events.create!(name: "old", timestamp: 2.hours.ago)
    new_event = @project.events.create!(name: "new", timestamp: Time.current)

    events = @project.events.recent
    assert_equal new_event.id, events.first.id
  end

  test "by_name scope should filter by name" do
    @project.events.create!(name: "other_event", timestamp: Time.current)
    events = @project.events.by_name("user.signup")
    assert_equal 1, events.count
    assert_equal "user.signup", events.first.name
  end

  test "since scope should filter by timestamp" do
    old_event = @project.events.create!(name: "old", timestamp: 2.days.ago)
    new_event = @project.events.create!(name: "new", timestamp: 1.hour.ago)

    events = @project.events.since(1.day.ago)
    assert_includes events, new_event
    assert_not_includes events, old_event
  end

  test "until_time scope should filter by timestamp" do
    old_event = @project.events.create!(name: "old", timestamp: 2.days.ago)
    new_event = @project.events.create!(name: "new", timestamp: 1.hour.ago)

    events = @project.events.until_time(1.day.ago)
    assert_includes events, old_event
    assert_not_includes events, new_event
  end

  test "with_tag scope should filter by tag" do
    event_with_tag = @project.events.create!(
      name: "tagged",
      timestamp: Time.current,
      tags: { environment: "production" }
    )
    event_without_tag = @project.events.create!(
      name: "untagged",
      timestamp: Time.current,
      tags: { environment: "staging" }
    )

    events = @project.events.with_tag("environment", "production")
    assert_includes events.to_a, event_with_tag
    assert_not_includes events.to_a, event_without_tag
  end

  test "with_property scope should filter by property" do
    event_with_property = @project.events.create!(
      name: "test",
      timestamp: Time.current,
      properties: { plan: "enterprise" }
    )

    events = @project.events.with_property("plan", "enterprise")
    assert_includes events.to_a, event_with_property
  end

  test "count_by_name should return counts grouped by name" do
    3.times { @project.events.create!(name: "event_a", timestamp: Time.current) }
    2.times { @project.events.create!(name: "event_b", timestamp: Time.current) }

    counts = Event.where(project: @project).count_by_name(since: 1.hour.ago)
    assert_equal 3, counts["event_a"]
    assert_equal 2, counts["event_b"]
  end

  test "stats should return event statistics" do
    @project.events.create!(name: "valued_event", timestamp: Time.current, value: 10.5)
    @project.events.create!(name: "valued_event", timestamp: Time.current, value: 20.5)

    stats = Event.where(project: @project).stats(since: 1.hour.ago)
    assert_kind_of Hash, stats
    assert stats[:total] > 0
    assert stats[:unique_names] > 0
    assert_not_nil stats[:with_value]
    assert_not_nil stats[:avg_value]
  end

  test "should store user_id" do
    event = @project.events.create!(
      name: "test",
      timestamp: Time.current,
      user_id: "user_123"
    )
    assert_equal "user_123", event.user_id
  end

  test "should store session_id" do
    event = @project.events.create!(
      name: "test",
      timestamp: Time.current,
      session_id: "session_xyz"
    )
    assert_equal "session_xyz", event.session_id
  end

  test "should store value" do
    event = @project.events.create!(
      name: "purchase",
      timestamp: Time.current,
      value: 99.99
    )
    assert_equal 99.99, event.value
  end

  test "should store environment" do
    event = @project.events.create!(
      name: "test",
      timestamp: Time.current,
      environment: "staging"
    )
    assert_equal "staging", event.environment
  end
end
