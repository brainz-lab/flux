# frozen_string_literal: true

module Dashboard
  class AnomaliesController < BaseController
    def index
      @since = parse_since(params[:since] || "24h")
      @anomalies = current_project.anomalies.since(@since).recent

      @anomalies = @anomalies.by_severity(params[:severity]) if params[:severity].present?
      @anomalies = @anomalies.unacknowledged if params[:unacknowledged] == "true"

      @anomalies = @anomalies.limit(50)

      @summary = {
        critical: current_project.anomalies.since(@since).critical.count,
        warning: current_project.anomalies.since(@since).warnings.count,
        info: current_project.anomalies.since(@since).by_severity("info").count,
        unacknowledged: current_project.anomalies.since(@since).unacknowledged.count
      }
    end

    def show
      @anomaly = current_project.anomalies.find(params[:id])
    end

    def acknowledge
      @anomaly = current_project.anomalies.find(params[:id])
      @anomaly.acknowledge!

      respond_to do |format|
        format.html { redirect_back fallback_location: dashboard_project_anomalies_path(current_project), notice: "Anomaly acknowledged." }
        format.turbo_stream
      end
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
