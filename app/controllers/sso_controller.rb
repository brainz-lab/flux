# frozen_string_literal: true

class SsoController < ApplicationController
  def callback
    token = params[:token]
    return redirect_to root_path, alert: "Missing token" unless token

    # Validate token with Platform
    project_data = validate_sso_token(token)

    if project_data
      session[:platform_project_id] = project_data["project_id"]
      session[:platform_user_id] = project_data["user_id"]

      # Ensure local project exists
      find_or_create_project(project_data)

      redirect_to params[:return_to] || dashboard_root_path
    else
      redirect_to root_path, alert: "Invalid SSO token"
    end
  end

  def logout
    session.delete(:platform_project_id)
    session.delete(:platform_user_id)

    redirect_to root_path, notice: "Logged out successfully"
  end

  private

  def validate_sso_token(token)
    platform_url = ENV.fetch("BRAINZLAB_PLATFORM_URL", "http://platform:3000")
    uri = URI.parse("#{platform_url}/api/v1/sso/validate")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = { token: token }.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      nil
    end
  rescue => e
    Rails.logger.error("[SSO] Token validation failed: #{e.message}")
    nil
  end

  def find_or_create_project(data)
    Project.find_or_create_by(platform_project_id: data["project_id"]) do |p|
      p.name = data["project_name"] || "Project"
      p.slug = data["project_slug"] || data["project_id"]
      p.environment = data["environment"] || "production"
    end
  end
end
