# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:timestamp) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "timestamp auto-set" do
    it "sets timestamp if not provided" do
      event = project.events.create!(name: "test.event")
      expect(event.timestamp).not_to be_nil
    end
  end

  describe "counter_cache" do
    it "increments project events_count" do
      expect {
        create(:event, project: project, timestamp: Time.current)
      }.to change { project.reload.events_count }.by(1)
    end
  end

  describe "JSONB fields" do
    it "stores properties as Hash" do
      event = create(:event, project: project, properties: { key: "value" }, timestamp: Time.current)
      expect(event.reload.properties).to eq("key" => "value")
    end

    it "stores tags as Hash" do
      event = create(:event, project: project, tags: { env: "production" }, timestamp: Time.current)
      expect(event.reload.tags).to eq("env" => "production")
    end
  end

  describe "scopes" do
    it ".recent orders by timestamp desc" do
      old = create(:event, project: project, name: "old", timestamp: 2.hours.ago)
      recent = create(:event, project: project, name: "recent", timestamp: 1.minute.ago)

      expect(project.events.recent.first.id).to eq(recent.id)
    end

    it ".by_name filters by name" do
      create(:event, project: project, name: "target", timestamp: Time.current)
      create(:event, project: project, name: "other", timestamp: Time.current)

      expect(project.events.by_name("target").count).to eq(1)
    end

    it ".since filters by timestamp" do
      old = create(:event, project: project, name: "old", timestamp: 2.days.ago)
      recent = create(:event, project: project, name: "recent", timestamp: 1.hour.ago)

      results = project.events.since(1.day.ago)
      expect(results).to include(recent)
      expect(results).not_to include(old)
    end

    it ".until_time filters by timestamp" do
      old = create(:event, project: project, name: "old", timestamp: 2.days.ago)
      recent = create(:event, project: project, name: "recent", timestamp: 1.hour.ago)

      results = project.events.until_time(1.day.ago)
      expect(results).to include(old)
      expect(results).not_to include(recent)
    end

    it ".with_tag filters by tag" do
      create(:event, project: project, name: "tagged", tags: { env: "production" }, timestamp: Time.current)
      create(:event, project: project, name: "untagged", tags: {}, timestamp: Time.current)

      expect(project.events.with_tag("env", "production").count).to eq(1)
    end

    it ".with_property filters by property" do
      create(:event, project: project, name: "with_prop", properties: { plan: "pro" }, timestamp: Time.current)
      create(:event, project: project, name: "without", properties: {}, timestamp: Time.current)

      expect(project.events.with_property("plan", "pro").count).to eq(1)
    end
  end

  describe ".count_by_name" do
    it "groups events by name" do
      3.times { create(:event, project: project, name: "event_a", timestamp: Time.current) }
      2.times { create(:event, project: project, name: "event_b", timestamp: Time.current) }

      result = project.events.count_by_name
      expect(result["event_a"]).to eq(3)
      expect(result["event_b"]).to eq(2)
    end
  end

  describe ".stats" do
    it "returns statistics" do
      create(:event, project: project, name: "test", timestamp: Time.current, value: 10)
      create(:event, project: project, name: "test", timestamp: Time.current, value: 20)

      result = project.events.stats
      expect(result).to be_a(Hash)
    end
  end

  describe "field storage" do
    it "stores user_id" do
      event = create(:event, project: project, name: "test", user_id: "user_123", timestamp: Time.current)
      expect(event.reload.user_id).to eq("user_123")
    end

    it "stores session_id" do
      event = create(:event, project: project, name: "test", session_id: "sess_456", timestamp: Time.current)
      expect(event.reload.session_id).to eq("sess_456")
    end

    it "stores value" do
      event = create(:event, project: project, name: "test", value: 42.5, timestamp: Time.current)
      expect(event.reload.value).to eq(42.5)
    end

    it "stores environment" do
      event = create(:event, project: project, name: "test", environment: "staging", timestamp: Time.current)
      expect(event.reload.environment).to eq("staging")
    end
  end
end
