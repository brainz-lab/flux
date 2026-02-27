# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnomalyDetectionJob, type: :job do
  let(:project) { create(:project) }

  describe "#perform" do
    it "detects anomaly for specific event" do
      # Create baseline (yesterday)
      10.times { create(:event, project: project, name: "test.event", timestamp: 25.hours.ago) }

      # Create spike (today - 3x baseline)
      30.times { create(:event, project: project, name: "test.event", timestamp: 30.minutes.ago) }

      event = project.events.last

      expect {
        described_class.perform_now(event.id)
      }.to change(Anomaly, :count).by(1)

      anomaly = Anomaly.last
      expect(anomaly.source).to eq("event")
      expect(anomaly.source_name).to eq("test.event")
      expect(anomaly.anomaly_type).to eq("spike")
    end

    it "skips if event not found" do
      expect {
        described_class.perform_now(SecureRandom.uuid)
      }.not_to change(Anomaly, :count)
    end

    it "detects for all projects when no event_id given" do
      project2 = create(:project)

      # Create baseline and spike for project1
      10.times { create(:event, project: project, name: "event1", timestamp: 25.hours.ago) }
      30.times { create(:event, project: project, name: "event1", timestamp: 30.minutes.ago) }

      # Create baseline and spike for project2
      5.times { create(:event, project: project2, name: "event2", timestamp: 25.hours.ago) }
      20.times { create(:event, project: project2, name: "event2", timestamp: 30.minutes.ago) }

      described_class.perform_now

      expect(project.anomalies.where(source_name: "event1").exists?).to be true
      expect(project2.anomalies.where(source_name: "event2").exists?).to be true
    end

    it "detects metric anomalies" do
      create(:metric_definition, project: project, name: "test.metric", metric_type: "gauge")

      # Create baseline (yesterday)
      create(:metric_point, project: project, metric_name: "test.metric", value: 100, timestamp: 25.hours.ago)

      # Create spike (today - 3x baseline)
      create(:metric_point, project: project, metric_name: "test.metric", value: 350, timestamp: 30.minutes.ago)

      described_class.perform_now

      anomaly = project.anomalies.where(source: "metric").last
      expect(anomaly).to be_present
      expect(anomaly.source_name).to eq("test.metric")
    end

    it "handles errors gracefully" do
      expect { described_class.perform_now }.not_to raise_error
    end

    it "only processes recent events" do
      create(:event, project: project, name: "old.event", timestamp: 3.days.ago)
      expect { described_class.perform_now }.not_to raise_error
    end
  end
end
