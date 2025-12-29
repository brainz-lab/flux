# frozen_string_literal: true

module Dashboard
  class BaseController < ApplicationController
    before_action :authenticate_via_sso!
    before_action :set_project

    layout "dashboard"

    helper_method :current_project

    private

    def authenticate_via_sso!
      # In development, allow access
      return if Rails.env.development?

      unless session[:platform_user_id]
        platform_url = ENV.fetch("BRAINZLAB_PLATFORM_URL", "http://platform:3000")
        redirect_to "#{platform_url}/auth/sso?product=flux&return_to=#{request.url}", allow_other_host: true
      end
    end

    def set_project
      return unless params[:project_id].present?

      @project = Project.find_by(slug: params[:project_id]) || Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to dashboard_projects_path, alert: "Project not found"
    end

    def current_project
      @project
    end

    def require_project!
      redirect_to dashboard_projects_path, alert: "Please select a project" unless @project
    end
  end
end
