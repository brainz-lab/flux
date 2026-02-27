# frozen_string_literal: true

require "rails_helper"

RSpec.describe Anomaly, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_inclusion_of(:source).in_array(%w[metric event]) }
    it { is_expected.to validate_presence_of(:source_name) }
    it { is_expected.to validate_presence_of(:anomaly_type) }
    it { is_expected.to validate_inclusion_of(:anomaly_type).in_array(%w[spike drop trend seasonality]) }
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_inclusion_of(:severity).in_array(%w[info warning critical]) }
    it { is_expected.to validate_presence_of(:detected_at) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "scopes" do
    it ".recent orders by detected_at desc" do
      old = create(:anomaly, project: project, detected_at: 2.hours.ago)
      recent = create(:anomaly, project: project, detected_at: 1.minute.ago)

      expect(project.anomalies.recent.first.id).to eq(recent.id)
    end

    it ".unacknowledged filters unacknowledged anomalies" do
      acknowledged = create(:anomaly, project: project, acknowledged_at: Time.current)
      unacknowledged = create(:anomaly, project: project, acknowledged_at: nil)

      results = project.anomalies.unacknowledged
      expect(results).to include(unacknowledged)
      expect(results).not_to include(acknowledged)
    end

    it ".by_severity filters by severity" do
      critical = create(:anomaly, project: project, severity: "critical")
      warning = create(:anomaly, project: project, severity: "warning")

      expect(project.anomalies.by_severity("critical")).to include(critical)
      expect(project.anomalies.by_severity("critical")).not_to include(warning)
    end

    it ".since filters by detected_at" do
      old = create(:anomaly, project: project, detected_at: 2.days.ago)
      recent = create(:anomaly, project: project, detected_at: 1.hour.ago)

      results = project.anomalies.since(1.day.ago)
      expect(results).to include(recent)
      expect(results).not_to include(old)
    end

    it ".critical returns critical anomalies" do
      critical = create(:anomaly, project: project, severity: "critical")
      warning = create(:anomaly, project: project, severity: "warning")

      expect(project.anomalies.critical).to include(critical)
      expect(project.anomalies.critical).not_to include(warning)
    end

    it ".warnings returns warning anomalies" do
      critical = create(:anomaly, project: project, severity: "critical")
      warning = create(:anomaly, project: project, severity: "warning")

      expect(project.anomalies.warnings).to include(warning)
      expect(project.anomalies.warnings).not_to include(critical)
    end
  end

  describe "#acknowledge!" do
    it "sets acknowledged_at" do
      anomaly = create(:anomaly, project: project)
      anomaly.acknowledge!

      expect(anomaly.reload.acknowledged_at).not_to be_nil
    end
  end

  describe "type predicates" do
    it "#spike? returns true for spike" do
      anomaly = create(:anomaly, project: project, anomaly_type: "spike")
      expect(anomaly).to be_spike
    end

    it "#drop? returns true for drop" do
      anomaly = create(:anomaly, project: project, anomaly_type: "drop")
      expect(anomaly).to be_drop
    end
  end

  describe "severity predicates" do
    it "#critical? returns true for critical" do
      anomaly = create(:anomaly, project: project, severity: "critical")
      expect(anomaly).to be_critical
    end

    it "#warning? returns true for warning" do
      anomaly = create(:anomaly, project: project, severity: "warning")
      expect(anomaly).to be_warning
    end

    it "#info? returns true for info" do
      anomaly = create(:anomaly, project: project, severity: "info")
      expect(anomaly).to be_info
    end
  end

  describe "#deviation_description" do
    it "returns description for positive deviation" do
      anomaly = create(:anomaly, project: project, deviation_percent: 150.0)
      expect(anomaly.deviation_description).to be_a(String)
      expect(anomaly.deviation_description).to include("150")
    end

    it "returns description for negative deviation" do
      anomaly = create(:anomaly, project: project, deviation_percent: -50.0)
      expect(anomaly.deviation_description).to be_a(String)
    end

    it "handles nil deviation" do
      anomaly = create(:anomaly, project: project, deviation_percent: nil)
      expect(anomaly.deviation_description).not_to be_nil
    end
  end

  describe "context JSONB" do
    it "stores context as Hash" do
      anomaly = create(:anomaly, project: project, context: { threshold: 100, period: "1h" })
      expect(anomaly.reload.context).to eq("threshold" => 100, "period" => "1h")
    end
  end
end
