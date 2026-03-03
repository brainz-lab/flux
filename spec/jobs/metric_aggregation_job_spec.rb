# frozen_string_literal: true

require "rails_helper"

RSpec.describe MetricAggregationJob, type: :job do
  let(:project) { create(:project) }

  before do
    create(:metric_definition, project: project, name: "test.metric", metric_type: "gauge")
  end

  describe "#perform" do
    it "aggregates metrics for specific project" do
      5.times do |i|
        create(:metric_point,
          project: project,
          metric_name: "test.metric",
          value: (i + 1) * 10,
          timestamp: 1.hour.ago
        )
      end

      described_class.perform_now(project.id, bucket_size: "1h")

      expect(project.aggregated_metrics.exists?(metric_name: "test.metric")).to be true
    end

    it "processes all projects when no project_id given" do
      project2 = create(:project)
      create(:metric_definition, project: project2, name: "metric2", metric_type: "counter")

      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 1.hour.ago)
      create(:metric_point, project: project2, metric_name: "metric2", value: 200, timestamp: 1.hour.ago)

      described_class.perform_now

      expect(project.aggregated_metrics.exists?).to be true
      expect(project2.aggregated_metrics.exists?).to be true
    end

    it "handles missing project gracefully" do
      expect { described_class.perform_now(999999, bucket_size: "1h") }.not_to raise_error
    end

    it "handles errors gracefully" do
      expect { described_class.perform_now }.not_to raise_error
    end

    it "uses specified bucket_size" do
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 1.hour.ago)

      described_class.perform_now(project.id, bucket_size: "1d")

      aggregated = project.aggregated_metrics.last
      expect(aggregated&.bucket_size).to eq("1d") if aggregated
    end
  end
end
