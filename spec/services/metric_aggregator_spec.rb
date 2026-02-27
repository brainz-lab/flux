# frozen_string_literal: true

require "rails_helper"

RSpec.describe MetricAggregator, type: :service do
  let(:project) { create(:project) }
  let(:aggregator) { described_class.new(project) }

  describe "#aggregate" do
    it "creates aggregated metric" do
      bucket_time = 1.hour.ago.beginning_of_hour

      5.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: (i + 1) * 10,
          timestamp: bucket_time + (i * 10).minutes
        )
      end

      expect {
        aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)
      }.to change(AggregatedMetric, :count).by(1)

      aggregated = AggregatedMetric.last
      expect(aggregated.metric_name).to eq("test.metric")
      expect(aggregated.bucket_size).to eq("1h")
      expect(aggregated.bucket_time).to eq(bucket_time)
      expect(aggregated.count).to eq(5)
    end

    it "calculates statistics correctly" do
      bucket_time = 1.hour.ago.beginning_of_hour
      values = [10, 20, 30, 40, 50]

      values.each do |value|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: value,
          timestamp: bucket_time + 10.minutes
        )
      end

      aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

      aggregated = AggregatedMetric.last
      expect(aggregated.count).to eq(5)
      expect(aggregated.sum).to eq(150)
      expect(aggregated.avg).to eq(30.0)
      expect(aggregated.min).to eq(10)
      expect(aggregated.max).to eq(50)
    end

    it "calculates percentiles with enough data" do
      bucket_time = 1.hour.ago.beginning_of_hour

      20.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: i + 1,
          timestamp: bucket_time + (i * 2).minutes
        )
      end

      aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

      aggregated = AggregatedMetric.last
      expect(aggregated.p50).not_to be_nil
      expect(aggregated.p95).not_to be_nil
      expect(aggregated.p99).not_to be_nil
    end

    it "skips percentiles with insufficient data" do
      bucket_time = 1.hour.ago.beginning_of_hour

      5.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: i + 1,
          timestamp: bucket_time + (i * 10).minutes
        )
      end

      aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

      aggregated = AggregatedMetric.last
      expect(aggregated.p50).to be_nil
      expect(aggregated.p95).to be_nil
      expect(aggregated.p99).to be_nil
    end

    it "returns nil with no data" do
      bucket_time = 1.hour.ago.beginning_of_hour
      result = aggregator.aggregate("nonexistent", bucket_size: "1h", bucket_time: bucket_time)

      expect(result).to be_nil
      expect(AggregatedMetric.count).to eq(0)
    end

    it "upserts existing aggregation" do
      bucket_time = 1.hour.ago.beginning_of_hour

      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: bucket_time + 10.minutes)
      aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

      create(:metric_point, project: project, metric_name: "test.metric", value: 200, timestamp: bucket_time + 20.minutes)

      expect {
        aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)
      }.not_to change(AggregatedMetric, :count)

      aggregated = AggregatedMetric.last
      expect(aggregated.count).to eq(2)
    end

    it "handles different bucket sizes" do
      bucket_time = 1.day.ago.beginning_of_day

      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: bucket_time + 1.hour)

      aggregator.aggregate("test.metric", bucket_size: "1d", bucket_time: bucket_time)

      aggregated = AggregatedMetric.last
      expect(aggregated.bucket_size).to eq("1d")
    end

    it "skips nil values" do
      bucket_time = 1.hour.ago.beginning_of_hour

      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: bucket_time + 10.minutes)
      create(:metric_point, project: project, metric_name: "test.metric", value: nil, timestamp: bucket_time + 20.minutes)
      create(:metric_point, project: project, metric_name: "test.metric", value: 200, timestamp: bucket_time + 30.minutes)

      aggregator.aggregate("test.metric", bucket_size: "1h", bucket_time: bucket_time)

      aggregated = AggregatedMetric.last
      expect(aggregated.count).to eq(2)
      expect(aggregated.avg).to eq(150.0)
    end
  end

  describe "#aggregate_recent" do
    it "processes all metrics" do
      bucket_time = 2.hours.ago.beginning_of_hour

      create(:metric_point, project: project, metric_name: "metric1", value: 100, timestamp: bucket_time + 10.minutes)
      create(:metric_point, project: project, metric_name: "metric2", value: 200, timestamp: bucket_time + 20.minutes)

      aggregator.aggregate_recent(bucket_size: "1h")

      expect(project.aggregated_metrics.exists?(metric_name: "metric1")).to be true
      expect(project.aggregated_metrics.exists?(metric_name: "metric2")).to be true
    end
  end

  describe "#backfill" do
    it "creates aggregations for time range" do
      start_time = 3.hours.ago.beginning_of_hour

      3.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: 100,
          timestamp: start_time + (i * 1.hour) + 10.minutes
        )
      end

      aggregator.backfill("test.metric", since: start_time, bucket_size: "1h")

      expect(project.aggregated_metrics.where(metric_name: "test.metric").count).to be >= 3
    end

    it "handles 5 minute buckets" do
      start_time = 30.minutes.ago.beginning_of_hour

      3.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: 100,
          timestamp: start_time + (i * 5.minutes) + 1.minute
        )
      end

      aggregator.backfill("test.metric", since: start_time, bucket_size: "5m")

      expect(
        project.aggregated_metrics.where(metric_name: "test.metric", bucket_size: "5m").count
      ).to be >= 3
    end
  end

  describe "percentile calculation" do
    it "calculates percentiles correctly" do
      sorted = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

      p50 = aggregator.send(:percentile, sorted, 0.5)
      expect(p50).to be_within(0.1).of(5.5)

      p95 = aggregator.send(:percentile, sorted, 0.95)
      expect(p95).to be > 9
    end

    it "handles empty array" do
      result = aggregator.send(:percentile, [], 0.5)
      expect(result).to be_nil
    end
  end
end
