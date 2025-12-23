# frozen_string_literal: true

module Dashboard
  class OverviewController < BaseController
    def index
      @since = parse_since(params[:since] || "24h")

      @stats = {
        events_total: current_project.events.since(@since).count,
        metrics_total: current_project.metric_definitions.count,
        anomalies_count: current_project.anomalies.since(@since).unacknowledged.count,
        dashboards_count: current_project.flux_dashboards.count
      }

      @recent_events = current_project.events.since(@since).group(:name).count
                                      .sort_by { |_, v| -v }.first(10).to_h

      @recent_anomalies = current_project.anomalies.since(@since).recent.limit(5)
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
