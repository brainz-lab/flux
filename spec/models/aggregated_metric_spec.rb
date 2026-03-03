# frozen_string_literal: true

require "rails_helper"

RSpec.describe AggregatedMetric, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:metric_name) }
    it { is_expected.to validate_inclusion_of(:bucket_size).in_array(%w[1m 5m 1h 1d]) }
    it { is_expected.to validate_presence_of(:bucket_time) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "bucket sizes" do
    %w[1m 5m 1h 1d].each do |size|
      it "allows #{size} bucket size" do
        metric = create(:aggregated_metric, project: project, bucket_size: size)
        expect(metric).to be_valid
      end
    end

    it "rejects invalid bucket size" do
      metric = build(:aggregated_metric, project: project, bucket_size: "2h")
      expect(metric).not_to be_valid
    end
  end

  describe "scopes" do
    it ".by_metric filters by metric_name" do
      create(:aggregated_metric, project: project, metric_name: "target")
      create(:aggregated_metric, project: project, metric_name: "other")

      expect(project.aggregated_metrics.by_metric("target").count).to eq(1)
    end

    it ".by_bucket filters by bucket_size" do
      create(:aggregated_metric, project: project, bucket_size: "1h")
      create(:aggregated_metric, project: project, bucket_size: "1d")

      expect(project.aggregated_metrics.by_bucket("1h").count).to eq(1)
    end

    it ".since filters by bucket_time" do
      old = create(:aggregated_metric, project: project, bucket_time: 2.days.ago.beginning_of_hour)
      recent = create(:aggregated_metric, project: project, bucket_time: 1.hour.ago.beginning_of_hour)

      results = project.aggregated_metrics.since(1.day.ago)
      expect(results).to include(recent)
      expect(results).not_to include(old)
    end

    it ".until_time filters by bucket_time" do
      old = create(:aggregated_metric, project: project, bucket_time: 2.days.ago.beginning_of_hour)
      recent = create(:aggregated_metric, project: project, bucket_time: 1.hour.ago.beginning_of_hour)

      results = project.aggregated_metrics.until_time(1.day.ago)
      expect(results).to include(old)
      expect(results).not_to include(recent)
    end
  end

  describe ".for_chart" do
    it "returns data suitable for charting" do
      bucket_time = 2.hours.ago.beginning_of_hour
      create(:aggregated_metric, project: project, metric_name: "test", bucket_size: "1h", bucket_time: bucket_time)

      result = project.aggregated_metrics.for_chart("test", bucket_size: "1h")
      expect(result).to respond_to(:each)
    end
  end

  describe "field storage" do
    it "stores count" do
      metric = create(:aggregated_metric, project: project, count: 42)
      expect(metric.reload.count).to eq(42)
    end

    it "stores sum" do
      metric = create(:aggregated_metric, project: project, sum: 1500.5)
      expect(metric.reload.sum).to eq(1500.5)
    end

    it "stores avg" do
      metric = create(:aggregated_metric, project: project, avg: 35.7)
      expect(metric.reload.avg).to eq(35.7)
    end

    it "stores min" do
      metric = create(:aggregated_metric, project: project, min: 5.0)
      expect(metric.reload.min).to eq(5.0)
    end

    it "stores max" do
      metric = create(:aggregated_metric, project: project, max: 200.0)
      expect(metric.reload.max).to eq(200.0)
    end

    it "stores p50" do
      metric = create(:aggregated_metric, project: project, p50: 30.0)
      expect(metric.reload.p50).to eq(30.0)
    end

    it "stores p95" do
      metric = create(:aggregated_metric, project: project, p95: 90.0)
      expect(metric.reload.p95).to eq(90.0)
    end

    it "stores p99" do
      metric = create(:aggregated_metric, project: project, p99: 99.0)
      expect(metric.reload.p99).to eq(99.0)
    end
  end
end
