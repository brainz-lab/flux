# frozen_string_literal: true

module Dashboard
  class ProjectsController < ApplicationController
    before_action :authenticate_via_sso!
    before_action :set_project, only: [ :show, :edit, :update, :settings ]
    before_action :redirect_to_platform_in_production, only: [ :new, :create ]

    layout "dashboard"

    def index
      if Rails.env.development?
        @projects = Project.order(created_at: :desc)
      elsif session[:platform_project_id]
        @projects = Project.where(platform_project_id: session[:platform_project_id])
                           .or(Project.where(archived_at: nil))
                           .order(created_at: :desc)
      else
        @projects = Project.none
      end
    end

    def show
      redirect_to dashboard_project_overview_path(@project)
    end

    def new
      @project = Project.new
    end

    def create
      @project = Project.new(project_params)
      @project.platform_project_id ||= "manual_#{SecureRandom.hex(8)}"

      if @project.save
        redirect_to dashboard_project_setup_path(@project), notice: "Project created!"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @project.update(project_params)
        redirect_to dashboard_project_overview_path(@project), notice: "Project updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def settings
    end

    private

    def authenticate_via_sso!
      # In development, allow access
      return if Rails.env.development?

      unless session[:platform_project_id]
        platform_url = ENV.fetch("BRAINZLAB_PLATFORM_EXTERNAL_URL", "https://platform.brainzlab.ai")
        redirect_to "#{platform_url}/auth/sso?product=flux&return_to=#{request.url}", allow_other_host: true
      end
    end

    def set_project
      @project = Project.find_by!(slug: params[:id])
    rescue ActiveRecord::RecordNotFound
      @project = Project.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:name, :description, :environment, :retention_days)
    end

    def redirect_to_platform_in_production
      return unless Rails.env.production?

      platform_url = ENV.fetch("BRAINZLAB_PLATFORM_EXTERNAL_URL", "https://platform.brainzlab.ai")
      redirect_to platform_url, allow_other_host: true
    end
  end
end
