# frozen_string_literal: true

module Mcp
  class Server
    TOOLS = {
      "flux_track" => Tools::FluxTrack,
      "flux_query" => Tools::FluxQuery,
      "flux_metric" => Tools::FluxMetric,
      "flux_dashboard" => Tools::FluxDashboard,
      "flux_anomalies" => Tools::FluxAnomalies
    }.freeze

    attr_reader :project

    def initialize(project)
      @project = project
    end

    def list_tools
      TOOLS.map do |name, klass|
        {
          name: name,
          description: klass::DESCRIPTION,
          inputSchema: klass::SCHEMA
        }
      end
    end

    def call_tool(name, arguments = {})
      tool_class = TOOLS[name]
      raise ArgumentError, "Unknown tool: #{name}" unless tool_class

      tool = tool_class.new(project)
      tool.call(arguments.with_indifferent_access)
    end

    def handle_rpc(request)
      method = request[:method]
      params = request[:params] || {}

      case method
      when "tools/list"
        { tools: list_tools }
      when "tools/call"
        tool_name = params[:name]
        arguments = params[:arguments] || {}
        { content: [ { type: "text", text: call_tool(tool_name, arguments).to_json } ] }
      when "initialize"
        {
          protocolVersion: "2024-11-05",
          capabilities: { tools: {} },
          serverInfo: {
            name: "flux-mcp-server",
            version: "1.0.0"
          }
        }
      else
        { error: { code: -32601, message: "Method not found: #{method}" } }
      end
    rescue => e
      { error: { code: -32603, message: e.message } }
    end
  end
end
