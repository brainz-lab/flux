# frozen_string_literal: true

require "rails_helper"

RSpec.describe FluxDashboard, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    subject { create(:flux_dashboard, project: project) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:slug).scoped_to(:project_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:widgets).dependent(:destroy) }
  end

  describe "slug generation" do
    it "generates slug from name" do
      dashboard = create(:flux_dashboard, project: project, name: "API Overview")
      expect(dashboard.slug).to eq("api-overview")
    end

    it "generates unique slug" do
      create(:flux_dashboard, project: project, name: "Dashboard", slug: "dashboard")
      dashboard2 = create(:flux_dashboard, project: project, name: "Dashboard")
      expect(dashboard2.slug).to start_with("dashboard")
      expect(dashboard2.slug).not_to eq("dashboard")
    end

    it "allows same slug across different projects" do
      project2 = create(:project)
      create(:flux_dashboard, project: project, name: "Dashboard")
      dashboard2 = create(:flux_dashboard, project: project2, name: "Dashboard")
      expect(dashboard2).to be_valid
    end
  end

  describe "#to_param" do
    it "returns slug" do
      dashboard = create(:flux_dashboard, project: project, name: "Test")
      expect(dashboard.to_param).to eq(dashboard.slug)
    end
  end

  describe "scopes" do
    it ".default_first orders defaults first" do
      regular = create(:flux_dashboard, project: project, is_default: false)
      default = create(:flux_dashboard, project: project, is_default: true)

      expect(project.flux_dashboards.default_first.first.id).to eq(default.id)
    end

    it ".public_only returns public dashboards" do
      public_dash = create(:flux_dashboard, project: project, is_public: true)
      private_dash = create(:flux_dashboard, project: project, is_public: false)

      results = project.flux_dashboards.public_only
      expect(results).to include(public_dash)
      expect(results).not_to include(private_dash)
    end
  end

  describe "#make_default!" do
    it "sets dashboard as default" do
      dashboard = create(:flux_dashboard, project: project)
      dashboard.make_default!
      expect(dashboard.reload.is_default).to be true
    end

    it "unsets other defaults" do
      first = create(:flux_dashboard, project: project, is_default: true)
      second = create(:flux_dashboard, project: project)
      second.make_default!

      expect(first.reload.is_default).to be false
      expect(second.reload.is_default).to be true
    end
  end

  describe "defaults" do
    it "is_default defaults to false" do
      dashboard = create(:flux_dashboard, project: project)
      expect(dashboard.is_default).to be false
    end

    it "is_public defaults to false" do
      dashboard = create(:flux_dashboard, project: project)
      expect(dashboard.is_public).to be false
    end
  end

  describe "destroying" do
    it "cascades to widgets" do
      dashboard = create(:flux_dashboard, project: project)
      create(:widget, flux_dashboard: dashboard)

      expect { dashboard.destroy }.to change(Widget, :count).by(-1)
    end
  end

  describe "layout JSONB" do
    it "stores layout as Hash" do
      dashboard = create(:flux_dashboard, project: project, layout: { columns: 12, rows: 8 })
      expect(dashboard.reload.layout).to eq("columns" => 12, "rows" => 8)
    end
  end
end
