# frozen_string_literal: true

module Api
  module V1
    class AnomaliesController < BaseController
      def index
        since = parse_time_range(params[:since] || "24h")
        anomalies = current_project.anomalies.since(since).recent

        anomalies = anomalies.by_severity(params[:severity]) if params[:severity].present?
        anomalies = anomalies.unacknowledged if params[:unacknowledged] == "true"

        anomalies = anomalies.limit(params[:limit] || 50)

        render_success(
          anomalies: anomalies.map { |a| anomaly_json(a) },
          total: current_project.anomalies.since(since).count,
          since: since.iso8601
        )
      end

      def show
        anomaly = current_project.anomalies.find_by(id: params[:id])
        return render_not_found("Anomaly not found") unless anomaly

        render_success(anomaly: anomaly_json(anomaly))
      end

      def acknowledge
        anomaly = current_project.anomalies.find_by(id: params[:id])
        return render_not_found("Anomaly not found") unless anomaly

        anomaly.acknowledge!
        render_success(acknowledged: true, id: anomaly.id)
      end

      def acknowledge_all
        since = parse_time_range(params[:since] || "24h")
        count = current_project.anomalies.since(since).unacknowledged.update_all(acknowledged: true)

        render_success(acknowledged: count)
      end

      private

      def anomaly_json(anomaly)
        {
          id: anomaly.id,
          source: anomaly.source,
          source_name: anomaly.source_name,
          anomaly_type: anomaly.anomaly_type,
          severity: anomaly.severity,
          expected_value: anomaly.expected_value,
          actual_value: anomaly.actual_value,
          deviation_percent: anomaly.deviation_percent,
          deviation_description: anomaly.deviation_description,
          detected_at: anomaly.detected_at,
          started_at: anomaly.started_at,
          ended_at: anomaly.ended_at,
          acknowledged: anomaly.acknowledged,
          context: anomaly.context
        }
      end
    end
  end
end
