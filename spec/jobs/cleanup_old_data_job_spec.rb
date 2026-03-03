# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupOldDataJob, type: :job do
  let(:project) { create(:project, retention_days: 90) }

  describe "#perform" do
    it "deletes old events" do
      old_events = 3.times.map do
        create(:event, project: project, name: "old.event", timestamp: 100.days.ago)
      end
      recent_events = 2.times.map do
        create(:event, project: project, name: "recent.event", timestamp: 10.days.ago)
      end

      described_class.perform_now

      old_events.each { |e| expect(Event.exists?(e.id)).to be false }
      recent_events.each { |e| expect(Event.exists?(e.id)).to be true }
    end

    it "deletes old anomalies (>30 days)" do
      old_anomaly = create(:anomaly, project: project, detected_at: 40.days.ago)
      recent_anomaly = create(:anomaly, project: project, detected_at: 10.days.ago)

      described_class.perform_now

      expect(Anomaly.exists?(old_anomaly.id)).to be false
      expect(Anomaly.exists?(recent_anomaly.id)).to be true
    end

    it "uses project retention_days" do
      project.update!(retention_days: 30)
      old_event = create(:event, project: project, name: "test", timestamp: 40.days.ago)

      described_class.perform_now

      expect(Event.exists?(old_event.id)).to be false
    end

    it "defaults to 90 days if retention_days not set" do
      project.update!(retention_days: nil)
      old_event = create(:event, project: project, name: "test", timestamp: 100.days.ago)
      newer_event = create(:event, project: project, name: "test", timestamp: 80.days.ago)

      described_class.perform_now

      expect(Event.exists?(old_event.id)).to be false
      expect(Event.exists?(newer_event.id)).to be true
    end

    it "processes all projects" do
      project2 = create(:project, retention_days: 90)
      old_event1 = create(:event, project: project, name: "test", timestamp: 100.days.ago)
      old_event2 = create(:event, project: project2, name: "test", timestamp: 100.days.ago)

      described_class.perform_now

      expect(Event.exists?(old_event1.id)).to be false
      expect(Event.exists?(old_event2.id)).to be false
    end

    it "handles errors gracefully" do
      expect { described_class.perform_now }.not_to raise_error
    end
  end
end
