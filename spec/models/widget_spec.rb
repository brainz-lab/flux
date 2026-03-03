# frozen_string_literal: true

require "rails_helper"

RSpec.describe Widget, type: :model do
  let(:project) { create(:project) }
  let(:dashboard) { create(:flux_dashboard, project: project) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:widget_type) }
    it { is_expected.to validate_inclusion_of(:widget_type).in_array(%w[number graph bar pie table heatmap list markdown]) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:flux_dashboard) }
  end

  describe "widget types" do
    %w[number graph bar pie table heatmap].each do |type|
      it "allows #{type} widget type" do
        widget = create(:widget, flux_dashboard: dashboard, widget_type: type)
        expect(widget).to be_valid
      end
    end

    it "rejects invalid widget type" do
      widget = build(:widget, flux_dashboard: dashboard, widget_type: "invalid")
      expect(widget).not_to be_valid
      expect(widget.errors[:widget_type]).to include("is not included in the list")
    end
  end

  describe "delegation" do
    it "delegates project to flux_dashboard" do
      widget = create(:widget, flux_dashboard: dashboard)
      expect(widget.project).to eq(project)
    end
  end

  describe ".by_position scope" do
    it "orders by position" do
      widget1 = create(:widget, flux_dashboard: dashboard, position: { x: 0, y: 1 })
      widget2 = create(:widget, flux_dashboard: dashboard, position: { x: 0, y: 0 })

      expect(dashboard.widgets.by_position.first.id).to eq(widget2.id)
    end
  end

  describe "query helpers" do
    it "#source returns query source" do
      widget = create(:widget, flux_dashboard: dashboard, query: { source: "metrics" })
      expect(widget.source).to eq("metrics")
    end

    it "#source defaults to metrics" do
      widget = create(:widget, flux_dashboard: dashboard, query: {})
      expect(widget.source).to eq("metrics")
    end

    it "#metric_name returns query metric" do
      widget = create(:widget, flux_dashboard: dashboard, query: { metric: "api.requests" })
      expect(widget.metric_name).to eq("api.requests")
    end

    it "#event_name returns query event" do
      widget = create(:widget, flux_dashboard: dashboard, query: { event: "user.signup" })
      expect(widget.event_name).to eq("user.signup")
    end

    it "#aggregation returns query aggregation" do
      widget = create(:widget, flux_dashboard: dashboard, query: { aggregation: "sum" })
      expect(widget.aggregation).to eq("sum")
    end

    it "#aggregation defaults to avg" do
      widget = create(:widget, flux_dashboard: dashboard, query: {})
      expect(widget.aggregation).to eq("avg")
    end

    it "#filters returns query filters" do
      widget = create(:widget, flux_dashboard: dashboard, query: { filters: { environment: "production" } })
      expect(widget.filters).to eq("environment" => "production")
    end

    it "#filters defaults to empty hash" do
      widget = create(:widget, flux_dashboard: dashboard, query: {})
      expect(widget.filters).to eq({})
    end

    it "#group_by returns query group_by" do
      widget = create(:widget, flux_dashboard: dashboard, query: { group_by: %w[region environment] })
      expect(widget.group_by).to eq(%w[region environment])
    end

    it "#group_by defaults to empty array" do
      widget = create(:widget, flux_dashboard: dashboard, query: {})
      expect(widget.group_by).to eq([])
    end

    it "#time_range returns query time_range" do
      widget = create(:widget, flux_dashboard: dashboard, widget_type: "graph", query: { time_range: "7d" })
      expect(widget.time_range).to eq("7d")
    end

    it "#time_range defaults to 24h" do
      widget = create(:widget, flux_dashboard: dashboard, widget_type: "graph", query: {})
      expect(widget.time_range).to eq("24h")
    end
  end

  describe "display helpers" do
    it "#color returns display color" do
      widget = create(:widget, flux_dashboard: dashboard, display: { color: "#FF0000" })
      expect(widget.color).to eq("#FF0000")
    end

    it "#color defaults to blue" do
      widget = create(:widget, flux_dashboard: dashboard, display: {})
      expect(widget.color).to eq("#3B82F6")
    end

    it "#format returns display format" do
      widget = create(:widget, flux_dashboard: dashboard, display: { format: "number" })
      expect(widget.format).to eq("number")
    end

    it "#format defaults to number" do
      widget = create(:widget, flux_dashboard: dashboard, display: {})
      expect(widget.format).to eq("number")
    end

    it "#thresholds returns display thresholds" do
      widget = create(:widget, flux_dashboard: dashboard, display: { thresholds: { warning: 100, critical: 200 } })
      expect(widget.thresholds).to eq("warning" => 100, "critical" => 200)
    end

    it "#thresholds defaults to empty hash" do
      widget = create(:widget, flux_dashboard: dashboard, display: {})
      expect(widget.thresholds).to eq({})
    end

    it "#warning_threshold returns threshold value" do
      widget = create(:widget, flux_dashboard: dashboard, display: { thresholds: { warning: 100 } })
      expect(widget.warning_threshold).to eq(100)
    end

    it "#critical_threshold returns threshold value" do
      widget = create(:widget, flux_dashboard: dashboard, display: { thresholds: { critical: 200 } })
      expect(widget.critical_threshold).to eq(200)
    end
  end

  describe "position helpers" do
    it "#x returns position x coordinate" do
      widget = create(:widget, flux_dashboard: dashboard, position: { x: 4, y: 2, w: 6, h: 3 })
      expect(widget.x).to eq(4)
    end

    it "#x defaults to 0" do
      widget = create(:widget, flux_dashboard: dashboard, position: {})
      expect(widget.x).to eq(0)
    end

    it "#y returns position y coordinate" do
      widget = create(:widget, flux_dashboard: dashboard, position: { x: 0, y: 5 })
      expect(widget.y).to eq(5)
    end

    it "#width returns position width" do
      widget = create(:widget, flux_dashboard: dashboard, position: { w: 8 })
      expect(widget.width).to eq(8)
    end

    it "#width defaults to 4" do
      widget = create(:widget, flux_dashboard: dashboard, position: {})
      expect(widget.width).to eq(4)
    end

    it "#height returns position height" do
      widget = create(:widget, flux_dashboard: dashboard, position: { h: 3 })
      expect(widget.height).to eq(3)
    end

    it "#height defaults to 2" do
      widget = create(:widget, flux_dashboard: dashboard, position: {})
      expect(widget.height).to eq(2)
    end
  end

  describe "JSONB storage" do
    it "stores query as JSONB" do
      widget = create(:widget, flux_dashboard: dashboard, query: { source: "events" })
      expect(widget.reload.query).to be_a(Hash)
    end

    it "stores display as JSONB" do
      widget = create(:widget, flux_dashboard: dashboard, display: { color: "#000" })
      expect(widget.reload.display).to be_a(Hash)
    end

    it "stores position as JSONB" do
      widget = create(:widget, flux_dashboard: dashboard, position: { x: 0, y: 0 })
      expect(widget.reload.position).to be_a(Hash)
    end
  end
end
