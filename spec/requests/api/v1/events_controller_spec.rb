# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::EventsController", type: :request do
  let(:project) { create(:project) }
  let(:headers) { { "Authorization" => "Bearer #{project.api_key}" } }

  describe "POST /api/v1/events" do
    it "creates event with valid params" do
      expect {
        post "/api/v1/events", params: {
          name: "user.signup",
          properties: { plan: "pro" },
          tags: { environment: "production" }
        }, headers: headers
      }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["id"]).to be_present
      expect(json["name"]).to eq("user.signup")
    end

    it "sets timestamp if not provided" do
      post "/api/v1/events", params: { name: "test.event" }, headers: headers

      expect(response).to have_http_status(:created)
      expect(Event.last.timestamp).not_to be_nil
    end

    it "uses provided timestamp" do
      timestamp = 1.hour.ago
      post "/api/v1/events", params: {
        name: "test.event",
        timestamp: timestamp.iso8601
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(Event.last.timestamp.to_i).to be_within(1).of(timestamp.to_i)
    end

    it "returns error without name" do
      post "/api/v1/events", params: {}, headers: headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to be_present
    end

    it "requires authentication" do
      post "/api/v1/events", params: { name: "test" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects invalid api key" do
      post "/api/v1/events", params: { name: "test" },
        headers: { "Authorization" => "Bearer invalid_key" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts X-API-Key header" do
      post "/api/v1/events", params: { name: "test" },
        headers: { "X-API-Key" => project.api_key }
      expect(response).to have_http_status(:created)
    end

    it "accepts ingest_key" do
      post "/api/v1/events", params: { name: "test" },
        headers: { "Authorization" => "Bearer #{project.ingest_key}" }
      expect(response).to have_http_status(:created)
    end
  end

  describe "POST /api/v1/events/batch" do
    it "creates multiple events" do
      events = [
        { name: "event1", properties: { test: 1 } },
        { name: "event2", properties: { test: 2 } },
        { name: "event3", properties: { test: 3 } }
      ]

      expect {
        post "/api/v1/events/batch", params: { events: events }, headers: headers
      }.to change(Event, :count).by(3)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["ingested"]).to eq(3)
    end

    it "returns error with no events" do
      post "/api/v1/events/batch", params: {}, headers: headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("No events")
    end

    it "increments project events_count" do
      events = [ { name: "event1" }, { name: "event2" } ]
      initial_count = project.reload.events_count || 0

      post "/api/v1/events/batch", params: { events: events }, headers: headers

      expect(project.reload.events_count).to eq(initial_count + 2)
    end
  end

  describe "GET /api/v1/events" do
    it "lists events" do
      3.times { |i| create(:event, project: project, name: "event_#{i}", timestamp: Time.current) }

      get "/api/v1/events", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["events"].size).to eq(3)
      expect(json["total"]).to be_present
    end

    it "filters by name" do
      create(:event, project: project, name: "target", timestamp: Time.current)
      create(:event, project: project, name: "other", timestamp: Time.current)

      get "/api/v1/events", params: { name: "target" }, headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["events"].size).to eq(1)
      expect(json["events"][0]["name"]).to eq("target")
    end

    it "filters by since" do
      old = create(:event, project: project, name: "old", timestamp: 2.days.ago)
      recent = create(:event, project: project, name: "new", timestamp: 1.hour.ago)

      get "/api/v1/events", params: { since: "1d" }, headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      event_ids = json["events"].map { |e| e["id"] }
      expect(event_ids).to include(recent.id)
      expect(event_ids).not_to include(old.id)
    end

    it "limits results" do
      5.times { |i| create(:event, project: project, name: "event_#{i}", timestamp: Time.current) }

      get "/api/v1/events", params: { limit: 2 }, headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["events"].size).to eq(2)
    end

    it "supports offset" do
      3.times { |i| create(:event, project: project, name: "event_#{i}", timestamp: Time.current - i.hours) }

      get "/api/v1/events", params: { offset: 1, limit: 1 }, headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["events"].size).to eq(1)
    end
  end

  describe "GET /api/v1/events/:id" do
    it "returns event" do
      event = create(:event, project: project, name: "test", timestamp: Time.current)

      get "/api/v1/events/#{event.id}", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["event"]["id"]).to eq(event.id)
    end

    it "returns 404 for missing event" do
      get "/api/v1/events/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/events/count" do
    it "returns event count" do
      3.times { create(:event, project: project, name: "test", timestamp: Time.current) }

      get "/api/v1/events/count", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["count"]).to eq(3)
    end

    it "filters by name" do
      2.times { create(:event, project: project, name: "target", timestamp: Time.current) }
      3.times { create(:event, project: project, name: "other", timestamp: Time.current) }

      get "/api/v1/events/count", params: { name: "target" }, headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["count"]).to eq(2)
    end
  end

  describe "GET /api/v1/events/stats" do
    it "returns event statistics" do
      create(:event, project: project, name: "event_a", timestamp: Time.current, value: 10)
      create(:event, project: project, name: "event_b", timestamp: Time.current, value: 20)
      create(:event, project: project, name: "event_a", timestamp: Time.current)

      get "/api/v1/events/stats", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["stats"]["total"]).to eq(3)
      expect(json["stats"]["unique_names"]).to eq(2)
      expect(json["stats"]["with_value"]).to eq(2)
      expect(json["by_name"]).to be_present
      expect(json["by_name"]["event_a"]).to eq(2)
    end
  end
end
