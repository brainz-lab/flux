# frozen_string_literal: true

module Dashboard
  class MetricsController < BaseController
    def index
      @metrics = current_project.metric_definitions.alphabetical
    end

    def show
      @metric = current_project.metric_definitions.find_by!(name: params[:id])
      @since = parse_since(params[:since] || "24h")

      query = MetricQuery.new(current_project, @metric.name, { since: params[:since] || "24h" })
      @stats = query.stats
      @time_series = query.time_series
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
