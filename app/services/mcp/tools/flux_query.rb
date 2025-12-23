# frozen_string_literal: true

module Mcp
  module Tools
    class FluxQuery < Base
      DESCRIPTION = "Query events with filters and aggregations"
      SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "Event name to query (e.g., 'user.signup')"
          },
          since: {
            type: "string",
            description: "Time range: 1h, 24h, 7d, etc. (default: 24h)"
          },
          group_by: {
            type: "string",
            description: "Property to group results by"
          },
          limit: {
            type: "integer",
            description: "Maximum number of events to return (default: 100)"
          }
        },
        required: ["name"]
      }.freeze

      def call(args)
        since = parse_since(args[:since] || "24h")
        limit = (args[:limit] || 100).to_i.clamp(1, 500)

        events = @project.events
          .where(name: args[:name])
          .since(since)
          .recent
          .limit(limit)

        result = {
          name: args[:name],
          since: since.iso8601,
          total: @project.events.where(name: args[:name]).since(since).count,
          events: events.map do |e|
            {
              id: e.id,
              timestamp: e.timestamp.iso8601,
              properties: e.properties,
              value: e.value,
              user_id: e.user_id
            }
          end
        }

        # Add grouping if requested
        if args[:group_by].present?
          grouped = @project.events
            .where(name: args[:name])
            .since(since)
            .group("properties->>'#{args[:group_by]}'")
            .count
            .sort_by { |_, v| -v }
            .first(20)
            .to_h

          result[:grouped_by] = args[:group_by]
          result[:groups] = grouped
        end

        result
      end
    end
  end
end
