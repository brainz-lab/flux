# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class EventsControllerTest < ActionDispatch::IntegrationTest
      def setup
        @project = Project.create!(
          platform_project_id: "test_project",
          name: "Test Project"
        )
        @headers = { "Authorization" => "Bearer #{@project.api_key}" }
      end

      test "create should create event with valid params" do
        assert_difference "Event.count", 1 do
          post "/api/v1/events", params: {
            name: "user.signup",
            properties: { plan: "pro" },
            tags: { environment: "production" }
          }, headers: @headers
        end

        assert_response :created
        json = JSON.parse(response.body)
        assert json["id"]
        assert_equal "user.signup", json["name"]
      end

      test "create should set timestamp if not provided" do
        post "/api/v1/events", params: { name: "test.event" }, headers: @headers

        assert_response :created
        event = Event.last
        assert_not_nil event.timestamp
      end

      test "create should use provided timestamp" do
        timestamp = 1.hour.ago
        post "/api/v1/events", params: {
          name: "test.event",
          timestamp: timestamp.iso8601
        }, headers: @headers

        assert_response :created
        event = Event.last
        assert_in_delta timestamp.to_i, event.timestamp.to_i, 1
      end

      test "create should return error without name" do
        post "/api/v1/events", params: {}, headers: @headers

        assert_response :bad_request
        json = JSON.parse(response.body)
        assert json["error"]
      end

      test "create should require authentication" do
        post "/api/v1/events", params: { name: "test" }

        assert_response :unauthorized
      end

      test "create should reject invalid api key" do
        post "/api/v1/events", params: { name: "test" },
          headers: { "Authorization" => "Bearer invalid_key" }

        assert_response :unauthorized
      end

      test "create should accept X-API-Key header" do
        post "/api/v1/events", params: { name: "test" },
          headers: { "X-API-Key" => @project.api_key }

        assert_response :created
      end

      test "create should accept ingest_key" do
        post "/api/v1/events", params: { name: "test" },
          headers: { "Authorization" => "Bearer #{@project.ingest_key}" }

        assert_response :created
      end

      test "batch should create multiple events" do
        events = [
          { name: "event1", properties: { test: 1 } },
          { name: "event2", properties: { test: 2 } },
          { name: "event3", properties: { test: 3 } }
        ]

        assert_difference "Event.count", 3 do
          post "/api/v1/events/batch", params: { events: events }, headers: @headers
        end

        assert_response :created
        json = JSON.parse(response.body)
        assert_equal 3, json["ingested"]
      end

      test "batch should return error with no events" do
        post "/api/v1/events/batch", params: {}, headers: @headers

        assert_response :bad_request
        json = JSON.parse(response.body)
        assert_includes json["error"], "No events"
      end

      test "batch should increment project events_count" do
        events = [
          { name: "event1" },
          { name: "event2" }
        ]

        initial_count = @project.reload.events_count || 0
        post "/api/v1/events/batch", params: { events: events }, headers: @headers

        assert_equal initial_count + 2, @project.reload.events_count
      end

      test "index should list events" do
        3.times { |i| @project.events.create!(name: "event_#{i}", timestamp: Time.current) }

        get "/api/v1/events", headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 3, json["events"].size
        assert json["total"]
      end

      test "index should filter by name" do
        @project.events.create!(name: "target", timestamp: Time.current)
        @project.events.create!(name: "other", timestamp: Time.current)

        get "/api/v1/events", params: { name: "target" }, headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 1, json["events"].size
        assert_equal "target", json["events"][0]["name"]
      end

      test "index should filter by since" do
        old = @project.events.create!(name: "old", timestamp: 2.days.ago)
        new = @project.events.create!(name: "new", timestamp: 1.hour.ago)

        get "/api/v1/events", params: { since: "1d" }, headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        event_ids = json["events"].map { |e| e["id"] }
        assert_includes event_ids, new.id
        assert_not_includes event_ids, old.id
      end

      test "index should limit results" do
        5.times { |i| @project.events.create!(name: "event_#{i}", timestamp: Time.current) }

        get "/api/v1/events", params: { limit: 2 }, headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 2, json["events"].size
      end

      test "index should support offset" do
        events = 3.times.map { |i| @project.events.create!(name: "event_#{i}", timestamp: Time.current - i.hours) }

        get "/api/v1/events", params: { offset: 1, limit: 1 }, headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 1, json["events"].size
      end

      test "show should return event" do
        event = @project.events.create!(name: "test", timestamp: Time.current)

        get "/api/v1/events/#{event.id}", headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal event.id, json["event"]["id"]
      end

      test "show should return 404 for missing event" do
        get "/api/v1/events/#{SecureRandom.uuid}", headers: @headers

        assert_response :not_found
      end

      test "count should return event count" do
        3.times { @project.events.create!(name: "test", timestamp: Time.current) }

        get "/api/v1/events/count", headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 3, json["count"]
      end

      test "count should filter by name" do
        2.times { @project.events.create!(name: "target", timestamp: Time.current) }
        3.times { @project.events.create!(name: "other", timestamp: Time.current) }

        get "/api/v1/events/count", params: { name: "target" }, headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 2, json["count"]
      end

      test "stats should return event statistics" do
        @project.events.create!(name: "event_a", timestamp: Time.current, value: 10)
        @project.events.create!(name: "event_b", timestamp: Time.current, value: 20)
        @project.events.create!(name: "event_a", timestamp: Time.current)

        get "/api/v1/events/stats", headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 3, json["stats"]["total"]
        assert_equal 2, json["stats"]["unique_names"]
        assert_equal 2, json["stats"]["with_value"]
        assert json["by_name"]
        assert_equal 2, json["by_name"]["event_a"]
      end
    end
  end
end
