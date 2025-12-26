# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class MetricsControllerTest < ActionDispatch::IntegrationTest
      def setup
        @project = Project.create!(
          platform_project_id: "test_project",
          name: "Test Project"
        )
        @headers = { "Authorization" => "Bearer #{@project.api_key}" }
      end

      test "create gauge should track metric" do
        assert_difference "MetricPoint.count", 1 do
          post "/api/v1/metrics", params: {
            type: "gauge",
            name: "cpu.usage",
            value: 75.5,
            tags: { host: "server1" }
          }, headers: @headers
        end

        assert_response :created
        json = JSON.parse(response.body)
        assert json["success"]
        assert_equal "cpu.usage", json["metric"]
        assert_equal "gauge", json["type"]
      end

      test "create counter should track metric" do
        assert_difference "MetricPoint.count", 1 do
          post "/api/v1/metrics", params: {
            type: "counter",
            name: "api.requests",
            value: 1
          }, headers: @headers
        end

        assert_response :created
      end

      test "create distribution should track metric" do
        assert_difference "MetricPoint.count", 1 do
          post "/api/v1/metrics", params: {
            type: "distribution",
            name: "response.time",
            value: 125.5
          }, headers: @headers
        end

        assert_response :created
        point = MetricPoint.last
        assert_equal 125.5, point.value
        assert_equal 125.5, point.sum
        assert_equal 1, point.count
      end

      test "create set should track metric" do
        assert_difference "MetricPoint.count", 1 do
          post "/api/v1/metrics", params: {
            type: "set",
            name: "active.users",
            value: "user_123"
          }, headers: @headers
        end

        assert_response :created
      end

      test "create should return error for invalid type" do
        post "/api/v1/metrics", params: {
          type: "invalid",
          name: "test"
        }, headers: @headers

        assert_response :bad_request
        json = JSON.parse(response.body)
        assert_includes json["error"], "Invalid metric type"
      end

      test "create should create metric definition" do
        assert_difference "MetricDefinition.count", 1 do
          post "/api/v1/metrics", params: {
            type: "gauge",
            name: "new.metric",
            value: 100,
            display_name: "New Metric",
            unit: "requests",
            description: "A test metric"
          }, headers: @headers
        end

        definition = MetricDefinition.last
        assert_equal "new.metric", definition.name
        assert_equal "gauge", definition.metric_type
        assert_equal "New Metric", definition.display_name
        assert_equal "requests", definition.unit
        assert_equal "A test metric", definition.description
      end

      test "create should reuse existing metric definition" do
        @project.metric_definitions.create!(name: "existing", metric_type: "gauge")

        assert_no_difference "MetricDefinition.count" do
          post "/api/v1/metrics", params: {
            type: "gauge",
            name: "existing",
            value: 100
          }, headers: @headers
        end

        assert_response :created
      end

      test "create should increment project metrics_count" do
        initial_count = @project.reload.metrics_count || 0
        post "/api/v1/metrics", params: {
          type: "gauge",
          name: "test",
          value: 100
        }, headers: @headers

        assert_equal initial_count + 1, @project.reload.metrics_count
      end

      test "create should require authentication" do
        post "/api/v1/metrics", params: {
          type: "gauge",
          name: "test",
          value: 100
        }

        assert_response :unauthorized
      end

      test "batch should create multiple metrics" do
        metrics = [
          { name: "metric1", value: 10 },
          { name: "metric2", value: 20 },
          { name: "metric3", value: 30 }
        ]

        assert_difference "MetricPoint.count", 3 do
          post "/api/v1/metrics/batch", params: { metrics: metrics }, headers: @headers
        end

        assert_response :created
        json = JSON.parse(response.body)
        assert_equal 3, json["ingested"]
      end

      test "batch should return error with no metrics" do
        post "/api/v1/metrics/batch", params: {}, headers: @headers

        assert_response :bad_request
        json = JSON.parse(response.body)
        assert_includes json["error"], "No metrics"
      end

      test "batch should increment project metrics_count" do
        metrics = [
          { name: "metric1", value: 10 },
          { name: "metric2", value: 20 }
        ]

        initial_count = @project.reload.metrics_count || 0
        post "/api/v1/metrics/batch", params: { metrics: metrics }, headers: @headers

        assert_equal initial_count + 2, @project.reload.metrics_count
      end

      test "index should list metric definitions" do
        @project.metric_definitions.create!(name: "metric1", metric_type: "gauge")
        @project.metric_definitions.create!(name: "metric2", metric_type: "counter")

        get "/api/v1/metrics", headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 2, json["metrics"].size
        assert_equal "metric1", json["metrics"][0]["name"]
      end

      test "index should return empty array with no definitions" do
        get "/api/v1/metrics", headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal [], json["metrics"]
      end

      test "show should return metric details" do
        definition = @project.metric_definitions.create!(
          name: "test.metric",
          metric_type: "gauge",
          unit: "ms",
          description: "Test metric"
        )
        @project.metric_points.create!(
          metric_name: "test.metric",
          value: 100,
          timestamp: Time.current
        )

        get "/api/v1/metrics/test.metric", headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal "test.metric", json["metric"]["name"]
        assert_equal "gauge", json["metric"]["type"]
        assert json["stats"]
      end

      test "show should return 404 for missing metric" do
        get "/api/v1/metrics/nonexistent", headers: @headers

        assert_response :not_found
      end

      test "query should return time series data" do
        definition = @project.metric_definitions.create!(
          name: "test.metric",
          metric_type: "gauge"
        )
        3.times do |i|
          @project.metric_points.create!(
            metric_name: "test.metric",
            value: i * 10,
            timestamp: i.hours.ago
          )
        end

        get "/api/v1/metrics/test.metric/query", params: { since: "24h" }, headers: @headers

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal "test.metric", json["metric"]
        assert json["data"].is_a?(Array)
      end

      test "query should filter by tags" do
        definition = @project.metric_definitions.create!(
          name: "test.metric",
          metric_type: "gauge"
        )
        @project.metric_points.create!(
          metric_name: "test.metric",
          value: 100,
          timestamp: Time.current,
          tags: { region: "us-east" }
        )
        @project.metric_points.create!(
          metric_name: "test.metric",
          value: 200,
          timestamp: Time.current,
          tags: { region: "us-west" }
        )

        get "/api/v1/metrics/test.metric/query",
          params: { tags: { region: "us-east" } },
          headers: @headers

        assert_response :success
      end

      test "counter should default value to 1" do
        post "/api/v1/metrics", params: {
          type: "counter",
          name: "counter.test"
        }, headers: @headers

        assert_response :created
        point = MetricPoint.last
        assert_equal 1, point.value
      end
    end
  end
end
