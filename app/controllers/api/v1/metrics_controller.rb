# frozen_string_literal: true

module Api
  module V1
    class MetricsController < BaseController
      def create
        case params[:type]
        when "gauge"
          track_gauge
        when "counter"
          track_counter
        when "distribution"
          track_distribution
        when "set"
          track_set
        else
          return render_bad_request("Invalid metric type. Use: gauge, counter, distribution, or set")
        end

        current_project.increment_metrics_count!
        render_created(success: true, metric: params[:name], type: params[:type])
      end

      def batch
        metrics_data = params[:metrics] || params[:_json] || []
        return render_bad_request("No metrics provided") if metrics_data.empty?

        timestamp = Time.current
        records = metrics_data.map do |m|
          {
            project_id: current_project.id,
            metric_name: m[:name],
            timestamp: m[:timestamp] || timestamp,
            value: m[:value],
            tags: m[:tags] || {}
          }
        end

        MetricPoint.insert_all(records)
        current_project.increment_metrics_count!(records.size)

        render_created(ingested: records.size)
      end

      def index
        definitions = current_project.metric_definitions.alphabetical

        render_success(
          metrics: definitions.map do |d|
            {
              name: d.name,
              display_name: d.display_name,
              type: d.metric_type,
              unit: d.unit,
              description: d.description
            }
          end
        )
      end

      def show
        definition = current_project.metric_definitions.find_by(name: params[:name])
        return render_not_found("Metric not found") unless definition

        since = parse_time_range(params[:since] || "24h")
        stats = MetricPoint.where(project: current_project, metric_name: params[:name])
                           .since(since).stats(params[:name])

        render_success(
          metric: {
            name: definition.name,
            display_name: definition.display_name,
            type: definition.metric_type,
            unit: definition.unit,
            description: definition.description
          },
          stats: stats,
          since: since.iso8601
        )
      end

      def query
        metric_name = params[:name]
        since = parse_time_range(params[:since] || "24h")
        bucket = params[:bucket] || "1 hour"
        aggregation = params[:aggregation] || "avg"

        points = MetricPoint.where(project: current_project, metric_name: metric_name)
                            .since(since)

        # Apply tag filters
        if params[:tags].present?
          params[:tags].each do |key, value|
            points = points.with_tag(key, value)
          end
        end

        # Get time series data
        data = points.time_series(metric_name, since: since, bucket: bucket)

        render_success(
          metric: metric_name,
          aggregation: aggregation,
          data: data.map { |row| { time: row.bucket, value: row.avg_value, count: row.count } },
          since: since.iso8601,
          bucket: bucket
        )
      end

      private

      def track_gauge
        find_or_create_definition("gauge")

        MetricPoint.create!(
          project: current_project,
          metric_name: params[:name],
          timestamp: params[:timestamp] || Time.current,
          value: params[:value],
          tags: params[:tags] || {}
        )
      end

      def track_counter
        find_or_create_definition("counter")

        MetricPoint.create!(
          project: current_project,
          metric_name: params[:name],
          timestamp: params[:timestamp] || Time.current,
          value: params[:value] || 1,
          tags: params[:tags] || {}
        )
      end

      def track_distribution
        find_or_create_definition("distribution")

        MetricPoint.create!(
          project: current_project,
          metric_name: params[:name],
          timestamp: params[:timestamp] || Time.current,
          value: params[:value],
          sum: params[:value],
          count: 1,
          min: params[:value],
          max: params[:value],
          tags: params[:tags] || {}
        )
      end

      def track_set
        find_or_create_definition("set")

        # For sets, we track the value and cardinality
        MetricPoint.create!(
          project: current_project,
          metric_name: params[:name],
          timestamp: params[:timestamp] || Time.current,
          value: nil,
          cardinality: 1,
          tags: (params[:tags] || {}).merge(_set_value: params[:value].to_s)
        )
      end

      def find_or_create_definition(metric_type)
        current_project.metric_definitions.find_or_create_by(name: params[:name]) do |d|
          d.metric_type = metric_type
          d.display_name = params[:display_name]
          d.unit = params[:unit]
          d.description = params[:description]
        end
      end
    end
  end
end
