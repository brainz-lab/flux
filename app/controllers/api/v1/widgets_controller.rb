# frozen_string_literal: true

module Api
  module V1
    class WidgetsController < BaseController
      before_action :set_dashboard
      before_action :set_widget, only: [:show, :update, :destroy]

      def index
        widgets = @dashboard.widgets.by_position

        render_success(
          widgets: widgets.map { |w| widget_json(w) }
        )
      end

      def show
        render_success(widget: widget_json(@widget))
      end

      def create
        widget = @dashboard.widgets.new(widget_params)

        if widget.save
          render_created(widget_json(widget))
        else
          render_bad_request(widget.errors.full_messages.join(", "))
        end
      end

      def update
        if @widget.update(widget_params)
          render_success(widget_json(@widget))
        else
          render_bad_request(@widget.errors.full_messages.join(", "))
        end
      end

      def destroy
        @widget.destroy
        render_success(deleted: true)
      end

      private

      def set_dashboard
        @dashboard = current_project.flux_dashboards.find_by(slug: params[:dashboard_id]) ||
                     current_project.flux_dashboards.find_by(id: params[:dashboard_id])
        render_not_found("Dashboard not found") unless @dashboard
      end

      def set_widget
        @widget = @dashboard.widgets.find_by(id: params[:id])
        render_not_found("Widget not found") unless @widget
      end

      def widget_params
        params.permit(:title, :widget_type,
                      query: {}, display: {}, position: {})
      end

      def widget_json(widget)
        {
          id: widget.id,
          title: widget.title,
          widget_type: widget.widget_type,
          query: widget.query,
          display: widget.display,
          position: widget.position
        }
      end
    end
  end
end
