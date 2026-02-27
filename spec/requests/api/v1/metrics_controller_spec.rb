# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::MetricsController", type: :request do
  let(:project) { create(:project) }
  let(:headers) { { "Authorization" => "Bearer #{project.api_key}" } }

  describe "POST /api/v1/metrics" do
    it "creates gauge metric" do
      expect {
        post "/api/v1/metrics", params: {
          type: "gauge",
          name: "cpu.usage",
          value: 75.5,
          tags: { host: "server1" }
        }, headers: headers
      }.to change(MetricPoint, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["metric"]).to eq("cpu.usage")
      expect(json["type"]).to eq("gauge")
    end

    it "creates counter metric" do
      expect {
        post "/api/v1/metrics", params: {
          type: "counter",
          name: "api.requests",
          value: 1
        }, headers: headers
      }.to change(MetricPoint, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "creates distribution metric" do
      expect {
        post "/api/v1/metrics", params: {
          type: "distribution",
          name: "response.time",
          value: 125.5
        }, headers: headers
      }.to change(MetricPoint, :count).by(1)

      expect(response).to have_http_status(:created)
      point = MetricPoint.last
      expect(point.value).to eq(125.5)
      expect(point.sum).to eq(125.5)
      expect(point.count).to eq(1)
    end

    it "creates set metric" do
      expect {
        post "/api/v1/metrics", params: {
          type: "set",
          name: "active.users",
          value: "user_123"
        }, headers: headers
      }.to change(MetricPoint, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns error for invalid type" do
      post "/api/v1/metrics", params: {
        type: "invalid",
        name: "test"
      }, headers: headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Invalid metric type")
    end

    it "creates metric definition" do
      expect {
        post "/api/v1/metrics", params: {
          type: "gauge",
          name: "new.metric",
          value: 100,
          display_name: "New Metric",
          unit: "requests",
          description: "A test metric"
        }, headers: headers
      }.to change(MetricDefinition, :count).by(1)

      definition = MetricDefinition.last
      expect(definition.name).to eq("new.metric")
      expect(definition.metric_type).to eq("gauge")
      expect(definition.display_name).to eq("New Metric")
      expect(definition.unit).to eq("requests")
      expect(definition.description).to eq("A test metric")
    end

    it "reuses existing metric definition" do
      create(:metric_definition, project: project, name: "existing", metric_type: "gauge")

      expect {
        post "/api/v1/metrics", params: {
          type: "gauge",
          name: "existing",
          value: 100
        }, headers: headers
      }.not_to change(MetricDefinition, :count)

      expect(response).to have_http_status(:created)
    end

    it "increments project metrics_count" do
      initial_count = project.reload.metrics_count || 0

      post "/api/v1/metrics", params: {
        type: "gauge",
        name: "test",
        value: 100
      }, headers: headers

      expect(project.reload.metrics_count).to eq(initial_count + 1)
    end

    it "requires authentication" do
      post "/api/v1/metrics", params: {
        type: "gauge",
        name: "test",
        value: 100
      }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/metrics/batch" do
    it "creates multiple metrics" do
      metrics = [
        { name: "metric1", value: 10 },
        { name: "metric2", value: 20 },
        { name: "metric3", value: 30 }
      ]

      expect {
        post "/api/v1/metrics/batch", params: { metrics: metrics }, headers: headers
      }.to change(MetricPoint, :count).by(3)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["ingested"]).to eq(3)
    end

    it "returns error with no metrics" do
      post "/api/v1/metrics/batch", params: {}, headers: headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("No metrics")
    end

    it "increments project metrics_count" do
      metrics = [
        { name: "metric1", value: 10 },
        { name: "metric2", value: 20 }
      ]
      initial_count = project.reload.metrics_count || 0

      post "/api/v1/metrics/batch", params: { metrics: metrics }, headers: headers

      expect(project.reload.metrics_count).to eq(initial_count + 2)
    end
  end

  describe "GET /api/v1/metrics" do
    it "lists metric definitions" do
      create(:metric_definition, project: project, name: "metric1", metric_type: "gauge")
      create(:metric_definition, project: project, name: "metric2", metric_type: "counter")

      get "/api/v1/metrics", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["metrics"].size).to eq(2)
      expect(json["metrics"][0]["name"]).to eq("metric1")
    end

    it "returns empty array with no definitions" do
      get "/api/v1/metrics", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["metrics"]).to eq([])
    end
  end

  describe "GET /api/v1/metrics/:name" do
    it "returns metric details" do
      create(:metric_definition, project: project, name: "test.metric", metric_type: "gauge", unit: "ms", description: "Test metric")
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: Time.current)

      get "/api/v1/metrics/test.metric", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["metric"]["name"]).to eq("test.metric")
      expect(json["metric"]["type"]).to eq("gauge")
      expect(json["stats"]).to be_present
    end

    it "returns 404 for missing metric" do
      get "/api/v1/metrics/nonexistent", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/metrics/:name/query" do
    it "returns time series data" do
      create(:metric_definition, project: project, name: "test.metric", metric_type: "gauge")
      3.times do |i|
        create(:metric_point, project: project, metric_name: "test.metric", value: i * 10, timestamp: i.hours.ago)
      end

      get "/api/v1/metrics/test.metric/query", params: { since: "24h" }, headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["metric"]).to eq("test.metric")
      expect(json["data"]).to be_an(Array)
    end

    it "filters by tags" do
      create(:metric_definition, project: project, name: "test.metric", metric_type: "gauge")
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: Time.current, tags: { region: "us-east" })
      create(:metric_point, project: project, metric_name: "test.metric", value: 200, timestamp: Time.current, tags: { region: "us-west" })

      get "/api/v1/metrics/test.metric/query",
        params: { tags: { region: "us-east" } },
        headers: headers

      expect(response).to have_http_status(:success)
    end
  end

  describe "counter default value" do
    it "defaults value to 1" do
      post "/api/v1/metrics", params: {
        type: "counter",
        name: "counter.test"
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(MetricPoint.last.value).to eq(1)
    end
  end
end
