# frozen_string_literal: true

module Mcp
  module Tools
    class FluxAnomalies < Base
      DESCRIPTION = "List detected anomalies in metrics and events"
      SCHEMA = {
        type: "object",
        properties: {
          since: {
            type: "string",
            description: "Time range: 1h, 24h, 7d, etc. (default: 24h)"
          },
          severity: {
            type: "string",
            enum: [ "info", "warning", "critical" ],
            description: "Filter by severity level"
          },
          unacknowledged: {
            type: "boolean",
            description: "Only show unacknowledged anomalies"
          },
          limit: {
            type: "integer",
            description: "Maximum number of anomalies to return (default: 50)"
          }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || "24h")
        limit = (args[:limit] || 50).to_i.clamp(1, 100)

        anomalies = @project.anomalies.since(since).recent
        anomalies = anomalies.by_severity(args[:severity]) if args[:severity].present?
        anomalies = anomalies.unacknowledged if args[:unacknowledged]

        total = anomalies.count
        anomalies = anomalies.limit(limit)

        {
          since: since.iso8601,
          total: total,
          summary: {
            critical: @project.anomalies.since(since).critical.count,
            warning: @project.anomalies.since(since).warnings.count,
            info: @project.anomalies.since(since).by_severity("info").count,
            unacknowledged: @project.anomalies.since(since).unacknowledged.count
          },
          anomalies: anomalies.map do |a|
            {
              id: a.id,
              source: a.source,
              source_name: a.source_name,
              type: a.anomaly_type,
              severity: a.severity,
              expected: a.expected_value&.round(2),
              actual: a.actual_value&.round(2),
              deviation: a.deviation_description,
              detected_at: a.detected_at.iso8601,
              acknowledged: a.acknowledged
            }
          end
        }
      end
    end
  end
end
