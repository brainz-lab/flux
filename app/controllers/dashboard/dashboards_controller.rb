# frozen_string_literal: true

module Dashboard
  class DashboardsController < BaseController
    before_action :set_dashboard, only: [:show, :edit, :update, :destroy]

    def index
      @dashboards = current_project.flux_dashboards.default_first
    end

    def show
      @widgets = @dashboard.widgets.by_position
    end

    def new
      @dashboard = current_project.flux_dashboards.new
    end

    def create
      @dashboard = current_project.flux_dashboards.new(dashboard_params)

      if @dashboard.save
        redirect_to dashboard_project_dashboard_path(current_project, @dashboard), notice: "Dashboard created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @dashboard.update(dashboard_params)
        redirect_to dashboard_project_dashboard_path(current_project, @dashboard), notice: "Dashboard updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @dashboard.destroy
      redirect_to dashboard_project_dashboards_path(current_project), notice: "Dashboard deleted."
    end

    private

    def set_dashboard
      @dashboard = current_project.flux_dashboards.find_by!(slug: params[:id])
    rescue ActiveRecord::RecordNotFound
      @dashboard = current_project.flux_dashboards.find(params[:id])
    end

    def dashboard_params
      params.require(:dashboard).permit(:name, :description, :is_default, :is_public)
    end
  end
end
