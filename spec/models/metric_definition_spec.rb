# frozen_string_literal: true

require "rails_helper"

RSpec.describe MetricDefinition, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    subject { create(:metric_definition, project: project) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
    it { is_expected.to validate_presence_of(:metric_type) }
    it { is_expected.to validate_inclusion_of(:metric_type).in_array(%w[gauge counter distribution set]) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "metric types" do
    %w[gauge counter distribution set].each do |type|
      it "allows #{type} metric type" do
        definition = create(:metric_definition, project: project, metric_type: type)
        expect(definition).to be_valid
      end
    end

    it "rejects invalid metric type" do
      definition = build(:metric_definition, project: project, metric_type: "invalid")
      expect(definition).not_to be_valid
      expect(definition.errors[:metric_type]).to include("is not included in the list")
    end
  end

  describe "unique name per project" do
    it "rejects duplicate names within same project" do
      create(:metric_definition, project: project, name: "cpu.usage")
      duplicate = build(:metric_definition, project: project, name: "cpu.usage")
      expect(duplicate).not_to be_valid
    end

    it "allows same name across different projects" do
      project2 = create(:project)
      create(:metric_definition, project: project, name: "cpu.usage")
      definition = build(:metric_definition, project: project2, name: "cpu.usage")
      expect(definition).to be_valid
    end
  end

  describe "scopes" do
    it ".by_type filters by metric_type" do
      create(:metric_definition, project: project, metric_type: "gauge")
      create(:metric_definition, project: project, metric_type: "counter")

      expect(project.metric_definitions.by_type("gauge").count).to eq(1)
    end

    it ".alphabetical orders by name" do
      create(:metric_definition, project: project, name: "zebra")
      create(:metric_definition, project: project, name: "alpha")

      expect(project.metric_definitions.alphabetical.first.name).to eq("alpha")
    end
  end

  describe "type predicates" do
    it "#gauge? returns true for gauge type" do
      definition = create(:metric_definition, project: project, metric_type: "gauge")
      expect(definition).to be_gauge
    end

    it "#counter? returns true for counter type" do
      definition = create(:metric_definition, project: project, metric_type: "counter")
      expect(definition).to be_counter
    end

    it "#distribution? returns true for distribution type" do
      definition = create(:metric_definition, project: project, metric_type: "distribution")
      expect(definition).to be_distribution
    end

    it "#set? returns true for set type" do
      definition = create(:metric_definition, project: project, metric_type: "set")
      expect(definition).to be_set
    end
  end

  describe "#formatted_unit" do
    it "formats ms as milliseconds" do
      definition = create(:metric_definition, project: project, unit: "ms")
      expect(definition.formatted_unit).to eq("milliseconds")
    end

    it "formats s as seconds" do
      definition = create(:metric_definition, project: project, unit: "s")
      expect(definition.formatted_unit).to eq("seconds")
    end

    it "formats bytes" do
      definition = create(:metric_definition, project: project, unit: "bytes")
      expect(definition.formatted_unit).to eq("bytes")
    end

    it "formats usd as USD" do
      definition = create(:metric_definition, project: project, unit: "usd")
      expect(definition.formatted_unit).to eq("USD")
    end

    it "returns custom unit as-is" do
      definition = create(:metric_definition, project: project, unit: "requests")
      expect(definition.formatted_unit).to eq("requests")
    end

    it "returns nil for nil unit" do
      definition = create(:metric_definition, project: project, unit: nil)
      expect(definition.formatted_unit).to be_nil
    end
  end
end
