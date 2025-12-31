# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!

      attr_reader :current_project

      private

      def authenticate!
        key = extract_api_key
        return render_unauthorized("Missing API key") unless key.present?

        @current_project = find_project_by_key(key)
        render_unauthorized("Invalid API key") unless @current_project
      end

      def extract_api_key
        # Try Authorization header first (Bearer token)
        auth_header = request.headers["Authorization"]
        if auth_header&.start_with?("Bearer ")
          return auth_header.sub("Bearer ", "")
        end

        # Try X-API-Key header
        request.headers["X-API-Key"] || params[:api_key]
      end

      def find_project_by_key(key)
        # Check both api_key and ingest_key
        Project.find_by(api_key: key) || Project.find_by(ingest_key: key)
      end

      def render_unauthorized(message = "Unauthorized")
        render json: { error: message }, status: :unauthorized
      end

      def render_not_found(message = "Not found")
        render json: { error: message }, status: :not_found
      end

      def render_bad_request(message = "Bad request")
        render json: { error: message }, status: :bad_request
      end

      def render_created(data)
        render json: data, status: :created
      end

      def render_success(data)
        render json: data, status: :ok
      end

      def parse_time_range(value)
        case value
        when /^(\d+)m$/ then $1.to_i.minutes.ago
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        when /^(\d+)w$/ then $1.to_i.weeks.ago
        else 24.hours.ago
        end
      end
    end
  end
end
