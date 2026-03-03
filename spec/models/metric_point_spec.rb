# frozen_string_literal: true

require "rails_helper"

RSpec.describe MetricPoint, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:metric_name) }
    it { is_expected.to validate_presence_of(:timestamp) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "timestamp auto-set" do
    it "sets timestamp if not provided" do
      point = project.metric_points.create!(metric_name: "test.metric", value: 100)
      expect(point.timestamp).not_to be_nil
    end
  end

  describe "value storage" do
    it "stores numeric value" do
      point = create(:metric_point, project: project, value: 99.5)
      expect(point.reload.value).to eq(99.5)
    end
  end

  describe "tags JSONB" do
    it "stores tags as Hash" do
      point = create(:metric_point, project: project, tags: { host: "server1" })
      expect(point.reload.tags).to eq("host" => "server1")
    end

    it "handles nil tags" do
      point = create(:metric_point, project: project, tags: nil)
      expect(point.reload.tags).to eq({})
    end
  end

  describe "scopes" do
    it ".recent orders by timestamp desc" do
      old = create(:metric_point, project: project, timestamp: 2.hours.ago)
      recent = create(:metric_point, project: project, timestamp: 1.minute.ago)

      expect(project.metric_points.recent.first.id).to eq(recent.id)
    end

    it ".by_metric filters by metric_name" do
      create(:metric_point, project: project, metric_name: "target")
      create(:metric_point, project: project, metric_name: "other")

      expect(project.metric_points.by_metric("target").count).to eq(1)
    end

    it ".since filters by timestamp" do
      old = create(:metric_point, project: project, timestamp: 2.days.ago)
      recent = create(:metric_point, project: project, timestamp: 1.hour.ago)

      results = project.metric_points.since(1.day.ago)
      expect(results).to include(recent)
      expect(results).not_to include(old)
    end

    it ".until_time filters by timestamp" do
      old = create(:metric_point, project: project, timestamp: 2.days.ago)
      recent = create(:metric_point, project: project, timestamp: 1.hour.ago)

      results = project.metric_points.until_time(1.day.ago)
      expect(results).to include(old)
      expect(results).not_to include(recent)
    end

    it ".with_tag filters by tag" do
      create(:metric_point, project: project, tags: { host: "server1" })
      create(:metric_point, project: project, tags: { host: "server2" })

      expect(project.metric_points.with_tag("host", "server1").count).to eq(1)
    end
  end

  describe ".latest_value" do
    it "returns the most recent value for a metric" do
      create(:metric_point, project: project, metric_name: "cpu", value: 50, timestamp: 2.hours.ago)
      create(:metric_point, project: project, metric_name: "cpu", value: 75, timestamp: 1.hour.ago)

      expect(project.metric_points.latest_value("cpu")).to eq(75)
    end
  end

  describe ".stats" do
    it "returns metric statistics" do
      create(:metric_point, project: project, metric_name: "test", value: 10)
      create(:metric_point, project: project, metric_name: "test", value: 20)

      result = project.metric_points.stats("test")
      expect(result).to be_a(Hash)
    end
  end

  describe "count and sample_count fields" do
    it "stores count" do
      point = create(:metric_point, project: project, count: 5)
      expect(point.reload.count).to eq(5)
    end

    it "stores sample_count" do
      point = create(:metric_point, project: project, sample_count: 100)
      expect(point.reload.sample_count).to eq(100)
    end
  end
end
