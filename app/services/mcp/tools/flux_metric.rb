# frozen_string_literal: true

module Mcp
  module Tools
    class FluxMetric < Base
      DESCRIPTION = "Get metric values and time series data"
      SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "Metric name (e.g., 'response_time', 'queue.depth')"
          },
          aggregation: {
            type: "string",
            enum: ["avg", "sum", "min", "max", "p95", "p99", "count"],
            description: "Aggregation function (default: avg)"
          },
          since: {
            type: "string",
            description: "Time range: 1h, 24h, 7d, etc. (default: 24h)"
          },
          bucket: {
            type: "string",
            description: "Time bucket for time series: 1m, 5m, 1h, 1d (auto-selected if not specified)"
          }
        },
        required: ["name"]
      }.freeze

      def call(args)
        query = MetricQuery.new(@project, args[:name], {
          since: args[:since] || "24h",
          aggregation: args[:aggregation] || "avg",
          bucket: args[:bucket]
        })

        result = query.execute

        {
          metric: args[:name],
          aggregation: args[:aggregation] || "avg",
          since: parse_since(args[:since] || "24h").iso8601,
          current_value: query.latest,
          stats: result[:stats],
          time_series: result[:data].last(50) # Limit time series points
        }
      end
    end
  end
end
