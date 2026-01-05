# frozen_string_literal: true

module Api
  module V1
    class EventsController < BaseController
      def create
        event = current_project.events.new(event_params)
        event.timestamp ||= Time.current

        if event.save
          # Queue anomaly detection asynchronously
          AnomalyDetectionJob.perform_later(event.id) if should_detect_anomalies?

          render_created(id: event.id, name: event.name)
        else
          render_bad_request(event.errors.full_messages.join(", "))
        end
      end

      def batch
        events_data = params[:events] || params[:_json] || []
        return render_bad_request("No events provided") if events_data.empty?

        timestamp = Time.current
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

        bulk_insert_events(records)
        current_project.increment_events_count!(records.size)

        render_created(ingested: records.size)
      end

      def index
        events = current_project.events.recent
        events = apply_filters(events)
        events = events.limit(params[:limit] || 100).offset(params[:offset] || 0)

        render_success(
          events: events.as_json(only: [ :id, :name, :timestamp, :properties, :tags, :user_id, :value ]),
          total: current_project.events.count,
          query: filter_params
        )
      end

      def show
        event = current_project.events.find_by(id: params[:id])
        return render_not_found("Event not found") unless event

        render_success(event: event)
      end

      def count
        since = parse_time_range(params[:since] || "24h")
        events = current_project.events.since(since)
        events = apply_filters(events)

        render_success(
          count: events.count,
          since: since.iso8601,
          query: filter_params
        )
      end

      def stats
        since = parse_time_range(params[:since] || "24h")
        events = current_project.events.since(since)
        events = apply_filters(events)

        render_success(
          stats: {
            total: events.count,
            unique_names: events.distinct.count(:name),
            with_value: events.where.not(value: nil).count,
            avg_value: events.where.not(value: nil).average(:value)&.round(2)
          },
          by_name: events.group(:name).count.sort_by { |_, v| -v }.first(20).to_h,
          since: since.iso8601,
          query: filter_params
        )
      end

      private

      def event_params
        params.permit(:name, :timestamp, :user_id, :session_id, :value,
                      :environment, :service, :host, :request_id,
                      properties: {}, tags: {})
      end

      def filter_params
        params.permit(:name, :since, :until, :user_id, :environment, :service)
      end

      def apply_filters(scope)
        scope = scope.by_name(params[:name]) if params[:name].present?
        scope = scope.since(parse_time_range(params[:since])) if params[:since].present?
        scope = scope.until_time(Time.parse(params[:until])) if params[:until].present?
        scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
        scope = scope.where(environment: params[:environment]) if params[:environment].present?
        scope = scope.where(service: params[:service]) if params[:service].present?
        scope
      end

      def should_detect_anomalies?
        # Only detect for production or if explicitly enabled
        current_project.environment == "production" ||
          current_project.settings["anomaly_detection_enabled"]
      end

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
    end
  end
end
