# frozen_string_literal: true

module Api
  module V1
    class DashboardsController < BaseController
      before_action :set_dashboard, only: [ :show, :update, :destroy ]

      def index
        dashboards = current_project.flux_dashboards.default_first

        render_success(
          dashboards: dashboards.map do |d|
            {
              id: d.id,
              name: d.name,
              slug: d.slug,
              description: d.description,
              is_default: d.is_default,
              is_public: d.is_public,
              widgets_count: d.widgets.count
            }
          end
        )
      end

      def show
        render_success(
          dashboard: {
            id: @dashboard.id,
            name: @dashboard.name,
            slug: @dashboard.slug,
            description: @dashboard.description,
            is_default: @dashboard.is_default,
            is_public: @dashboard.is_public,
            layout: @dashboard.layout,
            settings: @dashboard.settings
          },
          widgets: @dashboard.widgets.by_position.map do |w|
            {
              id: w.id,
              title: w.title,
              widget_type: w.widget_type,
              query: w.query,
              display: w.display,
              position: w.position
            }
          end
        )
      end

      def create
        dashboard = current_project.flux_dashboards.new(dashboard_params)

        if dashboard.save
          render_created(
            id: dashboard.id,
            slug: dashboard.slug,
            name: dashboard.name
          )
        else
          render_bad_request(dashboard.errors.full_messages.join(", "))
        end
      end

      def update
        if @dashboard.update(dashboard_params)
          render_success(
            id: @dashboard.id,
            slug: @dashboard.slug,
            name: @dashboard.name
          )
        else
          render_bad_request(@dashboard.errors.full_messages.join(", "))
        end
      end

      def destroy
        @dashboard.destroy
        render_success(deleted: true)
      end

      private

      def set_dashboard
        @dashboard = current_project.flux_dashboards.find_by(slug: params[:id]) ||
                     current_project.flux_dashboards.find_by(id: params[:id])
        render_not_found("Dashboard not found") unless @dashboard
      end

      def dashboard_params
        params.permit(:name, :slug, :description, :is_default, :is_public,
                      layout: {}, settings: {})
      end
    end
  end
end
