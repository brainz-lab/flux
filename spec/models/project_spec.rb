# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project, type: :model do
  subject(:project) { create(:project) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:platform_project_id) }
    it { is_expected.to validate_uniqueness_of(:platform_project_id) }
    it { is_expected.to validate_uniqueness_of(:api_key) }
    it { is_expected.to validate_uniqueness_of(:ingest_key) }
  end

  describe "associations" do
    it { is_expected.to have_many(:events).dependent(:destroy) }
    it { is_expected.to have_many(:metric_definitions).dependent(:destroy) }
    it { is_expected.to have_many(:metric_points).dependent(:destroy) }
    it { is_expected.to have_many(:aggregated_metrics).dependent(:destroy) }
    it { is_expected.to have_many(:flux_dashboards).dependent(:destroy) }
    it { is_expected.to have_many(:anomalies).dependent(:destroy) }
  end

  describe "key generation" do
    it "generates api_key with flx_api_ prefix" do
      new_project = create(:project)
      expect(new_project.api_key).to start_with("flx_api_")
    end

    it "generates ingest_key with flx_ingest_ prefix" do
      new_project = create(:project)
      expect(new_project.ingest_key).to start_with("flx_ingest_")
    end

    it "generates unique api_keys" do
      project1 = create(:project)
      project2 = create(:project)
      expect(project1.api_key).not_to eq(project2.api_key)
    end

    it "generates unique ingest_keys" do
      project1 = create(:project)
      project2 = create(:project)
      expect(project1.ingest_key).not_to eq(project2.ingest_key)
    end
  end

  describe "slug generation" do
    it "generates slug from name" do
      proj = create(:project, name: "My Project")
      expect(proj.slug).to eq("my-project")
    end

    it "generates unique slug when duplicate" do
      create(:project, name: "Duplicate", slug: "duplicate")
      proj2 = create(:project, name: "Duplicate")
      expect(proj2.slug).to start_with("duplicate")
      expect(proj2.slug).not_to eq("duplicate")
    end
  end

  describe "#to_param" do
    it "returns slug" do
      proj = create(:project, name: "Test Slug")
      expect(proj.to_param).to eq(proj.slug)
    end
  end

  describe ".active scope" do
    it "returns active projects" do
      active = create(:project, active: true)
      inactive = create(:project, active: false)

      expect(Project.active).to include(active)
      expect(Project.active).not_to include(inactive)
    end
  end

  describe ".find_or_create_for_platform!" do
    it "creates new project for unknown platform_project_id" do
      expect {
        Project.find_or_create_for_platform!("new_platform_id", name: "New")
      }.to change(Project, :count).by(1)
    end

    it "returns existing project for known platform_project_id" do
      existing = create(:project, platform_project_id: "known_id")

      result = Project.find_or_create_for_platform!("known_id", name: "Updated")
      expect(result.id).to eq(existing.id)
    end
  end

  describe "#increment_events_count!" do
    it "increments events_count" do
      initial = project.events_count || 0
      project.increment_events_count!(5)
      expect(project.reload.events_count).to eq(initial + 5)
    end
  end

  describe "#increment_metrics_count!" do
    it "increments metrics_count" do
      initial = project.metrics_count || 0
      project.increment_metrics_count!
      expect(project.reload.metrics_count).to eq(initial + 1)
    end
  end

  describe "#overview" do
    it "returns overview hash" do
      result = project.overview
      expect(result).to be_a(Hash)
    end
  end

  describe "#top_events" do
    it "returns top events" do
      create(:event, project: project, name: "event_a", timestamp: Time.current)
      create(:event, project: project, name: "event_a", timestamp: Time.current)
      create(:event, project: project, name: "event_b", timestamp: Time.current)

      result = project.top_events
      expect(result).to be_a(Hash)
    end
  end

  describe "#events_per_hour" do
    it "returns events per hour" do
      result = project.events_per_hour
      expect(result).to respond_to(:each)
    end
  end
end
