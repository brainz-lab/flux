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

          bulk_insert_events(records) if records.any?
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

          bulk_insert_metric_points(records) if records.any?
          metrics_ingested = records.size
          current_project.increment_metrics_count!(metrics_ingested)
        end

        render_created(
          events_ingested: events_ingested,
          metrics_ingested: metrics_ingested,
          total: events_ingested + metrics_ingested
        )
      end

      private

      # Raw SQL insert for events - works with TimescaleDB hypertables
      def bulk_insert_events(records)
        return if records.empty?

        conn = ActiveRecord::Base.connection
        columns = %w[id project_id name timestamp properties tags user_id session_id value environment service host created_at]

        values = records.map do |record|
          [
            conn.quote(record[:id]),
            conn.quote(record[:project_id]),
            conn.quote(record[:name]),
            conn.quote(record[:timestamp]),
            conn.quote(record[:properties].to_json),
            conn.quote(record[:tags].to_json),
            conn.quote(record[:user_id]),
            conn.quote(record[:session_id]),
            record[:value].nil? ? "NULL" : record[:value],
            conn.quote(record[:environment]),
            conn.quote(record[:service]),
            conn.quote(record[:host]),
            conn.quote(record[:created_at])
          ].join(", ")
        end

        sql = "INSERT INTO events (#{columns.join(', ')}) VALUES #{values.map { |v| "(#{v})" }.join(', ')}"
        conn.execute(sql)
      end

      # Raw SQL insert for metric points - works with TimescaleDB hypertables
      def bulk_insert_metric_points(records)
        return if records.empty?

        conn = ActiveRecord::Base.connection
        columns = %w[project_id metric_name timestamp value tags]

        values = records.map do |record|
          [
            conn.quote(record[:project_id]),
            conn.quote(record[:metric_name]),
            conn.quote(record[:timestamp]),
            record[:value].nil? ? "NULL" : record[:value],
            conn.quote(record[:tags].to_json)
          ].join(", ")
        end

        sql = "INSERT INTO metric_points (#{columns.join(', ')}) VALUES #{values.map { |v| "(#{v})" }.join(', ')}"
        conn.execute(sql)
      end
    end
  end
end
