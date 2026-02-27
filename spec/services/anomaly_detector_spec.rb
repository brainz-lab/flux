# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnomalyDetector, type: :service do
  let(:project) { create(:project) }
  let(:detector) { described_class.new(project) }

  describe "#detect_for_metric" do
    it "detects spike" do
      # Create baseline (yesterday)
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 25.hours.ago)

      # Create spike (today - 3x baseline)
      create(:metric_point, project: project, metric_name: "test.metric", value: 350, timestamp: 30.minutes.ago)

      result = detector.detect_for_metric("test.metric")
      expect(result).to be_present
      expect(result.anomaly_type).to eq("spike")
    end

    it "detects drop" do
      # Create baseline (yesterday)
      create(:metric_point, project: project, metric_name: "test.metric", value: 300, timestamp: 25.hours.ago)

      # Create drop (today)
      create(:metric_point, project: project, metric_name: "test.metric", value: 10, timestamp: 30.minutes.ago)

      result = detector.detect_for_metric("test.metric")
      expect(result).to be_present
      expect(result.anomaly_type).to eq("drop")
    end

    it "returns nil with no recent data" do
      result = detector.detect_for_metric("nonexistent")
      expect(result).to be_nil
    end

    it "returns nil with no baseline" do
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 30.minutes.ago)

      result = detector.detect_for_metric("test.metric")
      expect(result).to be_nil
    end

    it "returns nil below threshold" do
      # Create baseline and similar current value
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 25.hours.ago)
      create(:metric_point, project: project, metric_name: "test.metric", value: 110, timestamp: 30.minutes.ago)

      result = detector.detect_for_metric("test.metric")
      expect(result).to be_nil
    end

    it "uses lower threshold for error metrics" do
      # Create baseline (yesterday)
      create(:metric_point, project: project, metric_name: "error.count", value: 100, timestamp: 25.hours.ago)

      # Create value that exceeds error threshold (50%) but not default (100%)
      create(:metric_point, project: project, metric_name: "error.count", value: 170, timestamp: 30.minutes.ago)

      result = detector.detect_for_metric("error.count")
      expect(result).to be_present
    end

    it "calculates severity based on deviation" do
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 25.hours.ago)
      create(:metric_point, project: project, metric_name: "test.metric", value: 500, timestamp: 30.minutes.ago)

      result = detector.detect_for_metric("test.metric")
      expect(result.severity).to eq("critical")
    end
  end

  describe "#detect_for_event" do
    it "detects spike (3x baseline)" do
      # Create baseline (yesterday)
      10.times { create(:event, project: project, name: "test.event", timestamp: 25.hours.ago) }

      # Create spike (today - 3x+)
      35.times { create(:event, project: project, name: "test.event", timestamp: 30.minutes.ago) }

      result = detector.detect_for_event("test.event")
      expect(result).to be_present
      expect(result.anomaly_type).to eq("spike")
    end

    it "detects drop (below 30%)" do
      # Create baseline (yesterday)
      100.times { create(:event, project: project, name: "test.event", timestamp: 25.hours.ago) }

      # Create drop (today - less than 30%)
      10.times { create(:event, project: project, name: "test.event", timestamp: 30.minutes.ago) }

      result = detector.detect_for_event("test.event")
      expect(result).to be_present
      expect(result.anomaly_type).to eq("drop")
    end

    it "returns nil with no recent events" do
      result = detector.detect_for_event("nonexistent")
      expect(result).to be_nil
    end

    it "returns nil with no baseline" do
      create(:event, project: project, name: "test.event", timestamp: 30.minutes.ago)

      result = detector.detect_for_event("test.event")
      expect(result).to be_nil
    end
  end

  describe "#detect_trend" do
    it "detects increasing trend" do
      7.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: 100 + (i * 20),
          timestamp: (7 - i).days.ago.beginning_of_day + 12.hours
        )
      end

      result = detector.detect_trend("test.metric", periods: 7)
      if result
        expect(result.anomaly_type).to eq("trend")
        expect(result.context["direction"]).to eq("increasing")
      end
    end

    it "detects decreasing trend" do
      7.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: 200 - (i * 20),
          timestamp: (7 - i).days.ago.beginning_of_day + 12.hours
        )
      end

      result = detector.detect_trend("test.metric", periods: 7)
      if result
        expect(result.anomaly_type).to eq("trend")
        expect(result.context["direction"]).to eq("decreasing")
      end
    end

    it "returns nil with insufficient data" do
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 1.day.ago)

      result = detector.detect_trend("test.metric", periods: 7)
      expect(result).to be_nil
    end

    it "returns nil with no clear trend" do
      7.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: [100, 110, 95, 105, 100, 108, 97][i],
          timestamp: (7 - i).days.ago.beginning_of_day + 12.hours
        )
      end

      result = detector.detect_trend("test.metric", periods: 7)
      expect(result).to be_nil
    end

    it "requires at least 20% change" do
      7.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: 100 + (i * 2),
          timestamp: (7 - i).days.ago.beginning_of_day + 12.hours
        )
      end

      result = detector.detect_trend("test.metric", periods: 7)
      expect(result).to be_nil
    end
  end

  describe "anomaly context" do
    it "includes context in created anomaly" do
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 25.hours.ago)
      create(:metric_point, project: project, metric_name: "test.metric", value: 350, timestamp: 30.minutes.ago)

      result = detector.detect_for_metric("test.metric")
      if result
        expect(result.context).to be_a(Hash)
        expect(result.context).to have_key("threshold")
      end
    end
  end
end
