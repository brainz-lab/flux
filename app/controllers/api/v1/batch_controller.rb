# frozen_string_literal: true

module Api
  module V1
    class BatchController < BaseController
      def create
        timestamp = Time.current
        events_ingested = 0
        metrics_ingested = 0

        # Process events
        if params[:events].present?
          events_data = params[:events]
          records = events_data.map do |e|
            {
              id: SecureRandom.uuid,
              project_id: current_project.id,
              name: e[:name],
              timestamp: e[:timestamp] || timestamp,
              properties: e[:properties] || {},
              tags: e[:tags] || {},
              user_id: e[:user_id],
              session_id: e[:session_id],
              value: e[:value],
              environment: e[:environment] || current_project.environment,
              service: e[:service],
              host: e[:host],
              created_at: timestamp
            }
          end

          Event.insert_all(records) if records.any?
          events_ingested = records.size
          current_project.increment_events_count!(events_ingested)
        end

        # Process metrics
        if params[:metrics].present?
          metrics_data = params[:metrics]
          records = metrics_data.map do |m|
            {
              project_id: current_project.id,
              metric_name: m[:name],
              timestamp: m[:timestamp] || timestamp,
              value: m[:value],
              tags: m[:tags] || {}
            }
          end

          MetricPoint.insert_all(records) if records.any?
          metrics_ingested = records.size
          current_project.increment_metrics_count!(metrics_ingested)
        end

        render_created(
          events_ingested: events_ingested,
          metrics_ingested: metrics_ingested,
          total: events_ingested + metrics_ingested
        )
      end
    end
  end
end
