# frozen_string_literal: true

module Dashboard
  class OverviewController < BaseController
    def index
      @since = parse_since(params[:since] || "24h")
      @overview = current_project.overview(since: @since)

      # For backward compatibility with the view
      @stats = {
        events_total: @overview[:events_total],
        metrics_total: @overview[:metrics_total],
        anomalies_count: @overview[:anomalies_unacknowledged],
        dashboards_count: @overview[:dashboards_count]
      }

      @recent_events = @overview[:top_events]
      @recent_anomalies = @overview[:recent_anomalies]
    end

    private

    def parse_since(value)
      case value
      when /^(\d+)m$/ then $1.to_i.minutes.ago
      when /^(\d+)h$/ then $1.to_i.hours.ago
      when /^(\d+)d$/ then $1.to_i.days.ago
      else 24.hours.ago
      end
    end
  end
end
