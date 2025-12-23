# frozen_string_literal: true

module Dashboard
  class McpSetupController < BaseController
    def index
      @tools = [
        { name: "flux_track", description: "Track a custom event" },
        { name: "flux_query", description: "Query events with filters" },
        { name: "flux_metric", description: "Get metric time series" },
        { name: "flux_dashboard", description: "Get dashboard data" },
        { name: "flux_anomalies", description: "List detected anomalies" }
      ]
    end
  end
end
