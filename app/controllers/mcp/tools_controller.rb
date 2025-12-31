# frozen_string_literal: true

module Mcp
  class ToolsController < ActionController::API
    before_action :authenticate!

    def index
      render json: { tools: server.list_tools }
    end

    def call
      tool_name = params[:name]
      arguments = tool_params

      result = server.call_tool(tool_name, arguments)
      render json: result
    rescue ArgumentError => e
      render json: { error: e.message }, status: :not_found
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end

    def rpc
      request = JSON.parse(request.body.read, symbolize_names: true)
      result = server.handle_rpc(request)

      render json: {
        jsonrpc: "2.0",
        id: request[:id],
        **result
      }
    rescue JSON::ParserError
      render json: {
        jsonrpc: "2.0",
        error: { code: -32700, message: "Parse error" }
      }, status: :bad_request
    end

    private

    def authenticate!
      key = extract_api_key
      return render json: { error: "Missing API key" }, status: :unauthorized unless key.present?

      @project = Project.find_by(api_key: key) || Project.find_by(ingest_key: key)
      render json: { error: "Invalid API key" }, status: :unauthorized unless @project
    end

    def extract_api_key
      auth_header = request.headers["Authorization"]
      return auth_header.sub("Bearer ", "") if auth_header&.start_with?("Bearer ")

      request.headers["X-API-Key"] || params[:api_key]
    end

    def server
      @server ||= Mcp::Server.new(@project)
    end

    def tool_params
      params.permit!.except(:controller, :action, :name, :api_key).to_h
    end
  end
end
