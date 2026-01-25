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

      # Sync all user's projects from Platform
      sync_projects_from_platform(token)

      redirect_to params[:return_to] || dashboard_root_path, allow_other_host: true
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

  def sync_projects_from_platform(sso_token)
    projects_data = fetch_user_projects(sso_token)
    return unless projects_data

    platform_ids = projects_data.map { |d| d["id"].to_s }

    projects_data.each do |data|
      project = Project.find_or_initialize_by(platform_project_id: data["id"].to_s)
      project.name = data["name"]
      project.slug = data["slug"]
      project.environment = data["environment"] || "production"
      project.archived_at = nil
      project.save!
    end

    Project.where.not(platform_project_id: [nil, ""])
           .where.not(platform_project_id: platform_ids)
           .where(archived_at: nil)
           .update_all(archived_at: Time.current)

    Rails.logger.info("[SSO] Synced #{projects_data.count} projects from Platform")
  rescue => e
    Rails.logger.error("[SSO] Project sync failed: #{e.message}")
  end

  def fetch_user_projects(sso_token)
    uri = URI("#{platform_url}/api/v1/user/projects")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.path)
    request["Accept"] = "application/json"
    request["X-SSO-Token"] = sso_token

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)["projects"]
    else
      nil
    end
  rescue => e
    Rails.logger.error("[SSO] fetch_user_projects failed: #{e.message}")
    nil
  end

  def platform_url
    ENV.fetch("BRAINZLAB_PLATFORM_URL", "http://platform:3000")
  end
end
