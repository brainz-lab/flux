# frozen_string_literal: true

module Dashboard
  class DevToolsController < BaseController
    def index
      @stats = {
        events_count: current_project.events.count,
        metrics_count: current_project.metric_definitions.count,
        dashboards_count: current_project.flux_dashboards.count,
        anomalies_count: current_project.anomalies.count
      }
    end
  end
end
