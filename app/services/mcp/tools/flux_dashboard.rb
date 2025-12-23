# frozen_string_literal: true

module Mcp
  module Tools
    class FluxDashboard < Base
      DESCRIPTION = "Get dashboard data with all widget values"
      SCHEMA = {
        type: "object",
        properties: {
          dashboard: {
            type: "string",
            description: "Dashboard slug or ID (use 'default' for the default dashboard)"
          }
        }
      }.freeze

      def call(args)
        dashboard = find_dashboard(args[:dashboard])
        return { error: "Dashboard not found" } unless dashboard

        {
          name: dashboard.name,
          slug: dashboard.slug,
          description: dashboard.description,
          widgets: dashboard.widgets.by_position.map { |w| execute_widget(w) }
        }
      end

      private

      def find_dashboard(identifier)
        return @project.flux_dashboards.find_by(is_default: true) if identifier.blank? || identifier == "default"

        @project.flux_dashboards.find_by(slug: identifier) ||
          @project.flux_dashboards.find_by(id: identifier)
      end

      def execute_widget(widget)
        result = {
          id: widget.id,
          title: widget.title,
          type: widget.widget_type,
          position: widget.position
        }

        begin
          result[:data] = fetch_widget_data(widget)
        rescue => e
          result[:error] = e.message
        end

        result
      end

      def fetch_widget_data(widget)
        since = parse_since(widget.time_range)

        case widget.source
        when "metrics"
          fetch_metric_data(widget, since)
        when "events"
          fetch_event_data(widget, since)
        else
          { error: "Unknown source: #{widget.source}" }
        end
      end

      def fetch_metric_data(widget, since)
        query = MetricQuery.new(@project, widget.metric_name, {
          since: widget.time_range,
          aggregation: widget.aggregation
        })

        case widget.widget_type
        when "number"
          {
            value: query.latest,
            stats: query.stats
          }
        when "graph", "bar"
          {
            series: query.time_series.last(50)
          }
        else
          query.stats
        end
      end

      def fetch_event_data(widget, since)
        events = @project.events.where(name: widget.event_name).since(since)

        case widget.widget_type
        when "number"
          { value: events.count }
        when "graph", "bar"
          {
            series: events.group_by_hour(:timestamp).count.map do |time, count|
              { time: time.iso8601, value: count }
            end
          }
        when "table"
          {
            rows: events.recent.limit(20).map do |e|
              { timestamp: e.timestamp.iso8601, properties: e.properties, value: e.value }
            end
          }
        else
          { count: events.count }
        end
      end
    end
  end
end
