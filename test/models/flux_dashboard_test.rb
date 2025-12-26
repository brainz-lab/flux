# frozen_string_literal: true

require "test_helper"

class FluxDashboardTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(platform_project_id: "test_project", name: "Test")
    @dashboard = @project.flux_dashboards.create!(
      name: "Main Dashboard",
      description: "Primary monitoring dashboard"
    )
  end

  test "should be valid with valid attributes" do
    assert @dashboard.valid?
  end

  test "should require name" do
    dashboard = @project.flux_dashboards.new
    assert_not dashboard.valid?
    assert_includes dashboard.errors[:name], "can't be blank"
  end

  test "should require slug" do
    dashboard = @project.flux_dashboards.new(name: "Test")
    dashboard.slug = nil
    assert_not dashboard.valid?
    assert_includes dashboard.errors[:slug], "can't be blank"
  end

  test "should generate slug from name on create" do
    dashboard = @project.flux_dashboards.create!(name: "My Test Dashboard")
    assert_equal "my-test-dashboard", dashboard.slug
  end

  test "should generate unique slug when duplicate exists" do
    @project.flux_dashboards.create!(name: "Test")
    dashboard2 = @project.flux_dashboards.create!(name: "Test")
    assert_equal "test-1", dashboard2.slug
  end

  test "should have unique slug per project" do
    duplicate = @project.flux_dashboards.new(
      name: "Different",
      slug: @dashboard.slug
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should allow same slug in different projects" do
    other_project = Project.create!(platform_project_id: "other_project", name: "Other")
    dashboard = other_project.flux_dashboards.create!(
      name: "Dashboard",
      slug: @dashboard.slug
    )
    assert dashboard.valid?
  end

  test "should belong to project" do
    assert_equal @project, @dashboard.project
  end

  test "should have many widgets" do
    assert_respond_to @dashboard, :widgets
  end

  test "should use slug in to_param" do
    assert_equal @dashboard.slug, @dashboard.to_param
  end

  test "default_first scope should order by is_default then created_at" do
    old_default = @project.flux_dashboards.create!(
      name: "Old Default",
      is_default: true
    )
    # Make the first dashboard created not default
    @dashboard.update!(is_default: false)

    new_regular = @project.flux_dashboards.create!(
      name: "New Regular",
      is_default: false
    )

    dashboards = @project.flux_dashboards.default_first
    assert_equal old_default.id, dashboards.first.id
  end

  test "public_only scope should filter public dashboards" do
    public_dashboard = @project.flux_dashboards.create!(
      name: "Public",
      is_public: true
    )
    private_dashboard = @project.flux_dashboards.create!(
      name: "Private",
      is_public: false
    )

    dashboards = @project.flux_dashboards.public_only
    assert_includes dashboards, public_dashboard
    assert_not_includes dashboards, private_dashboard
  end

  test "make_default! should set dashboard as default" do
    @dashboard.update!(is_default: false)
    @dashboard.make_default!
    assert @dashboard.reload.is_default
  end

  test "make_default! should unset other default dashboards" do
    other_dashboard = @project.flux_dashboards.create!(
      name: "Other",
      is_default: true
    )
    @dashboard.make_default!

    assert @dashboard.reload.is_default
    assert_not other_dashboard.reload.is_default
  end

  test "should store description" do
    assert_equal "Primary monitoring dashboard", @dashboard.description
  end

  test "should default is_default to false" do
    dashboard = @project.flux_dashboards.create!(name: "Test")
    assert_not dashboard.is_default
  end

  test "should default is_public to false" do
    dashboard = @project.flux_dashboards.create!(name: "Test")
    assert_not dashboard.is_public
  end

  test "destroying dashboard should destroy widgets" do
    widget = @dashboard.widgets.create!(
      widget_type: "number",
      query: { metric: "test" },
      display: {},
      position: { x: 0, y: 0 }
    )

    assert_difference "Widget.count", -1 do
      @dashboard.destroy
    end
  end

  test "should allow layout to be stored" do
    dashboard = @project.flux_dashboards.create!(
      name: "Test",
      layout: { columns: 12, rows: 8 }
    )
    assert_equal 12, dashboard.layout["columns"]
  end
end
