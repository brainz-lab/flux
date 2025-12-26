# frozen_string_literal: true

module Dashboard
  class WidgetsController < BaseController
    before_action :set_dashboard
    before_action :set_widget, only: [:show, :edit, :update, :destroy]

    def index
      @widgets = @dashboard.widgets.by_position
    end

    def show
    end

    def new
      @widget = @dashboard.widgets.new
    end

    def create
      @widget = @dashboard.widgets.new(widget_params)

      if @widget.save
        redirect_to dashboard_project_dashboard_path(current_project, @dashboard), notice: "Widget added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @widget.update(widget_params)
        redirect_to dashboard_project_dashboard_path(current_project, @dashboard), notice: "Widget updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @widget.destroy
      redirect_to dashboard_project_dashboard_path(current_project, @dashboard), notice: "Widget removed."
    end

    private

    def set_dashboard
      @dashboard = current_project.flux_dashboards.find_by!(slug: params[:dashboard_id])
    rescue ActiveRecord::RecordNotFound
      @dashboard = current_project.flux_dashboards.find(params[:dashboard_id])
    end

    def set_widget
      @widget = @dashboard.widgets.find(params[:id])
    end

    def widget_params
      params.require(:widget).permit(:title, :widget_type, query: {}, display: {}, position: {})
    end
  end
end
