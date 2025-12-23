# frozen_string_literal: true

module Dashboard
  class BaseController < ApplicationController
    before_action :authenticate_via_sso!
    before_action :set_project

    layout "dashboard"

    helper_method :current_project

    private

    def authenticate_via_sso!
      if Rails.env.development?
        session[:platform_project_id] ||= "dev_project"
        return
      end

      unless session[:platform_project_id]
        platform_url = ENV.fetch("BRAINZLAB_PLATFORM_URL", "http://platform:3000")
        redirect_to "#{platform_url}/auth/sso?product=flux&return_to=#{request.url}", allow_other_host: true
      end
    end

    def set_project
      @project = Project.find_or_create_for_platform!(
        platform_project_id: session[:platform_project_id],
        name: Rails.env.development? ? "Development" : nil,
        environment: Rails.env.development? ? "development" : "production"
      )
    rescue ActiveRecord::RecordInvalid => e
      render plain: "Failed to initialize project: #{e.message}", status: :internal_server_error
    end

    def current_project
      @project
    end
  end
end
