# frozen_string_literal: true

module Mcp
  module Tools
    class FluxTrack < Base
      DESCRIPTION = "Track a custom event"
      SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "Event name (e.g., 'user.signup', 'order.completed')"
          },
          properties: {
            type: "object",
            description: "Custom event properties"
          },
          value: {
            type: "number",
            description: "Optional numeric value for the event"
          },
          user_id: {
            type: "string",
            description: "Optional user identifier"
          }
        },
        required: [ "name" ]
      }.freeze

      def call(args)
        event = @project.events.create!(
          name: args[:name],
          properties: args[:properties] || {},
          value: args[:value],
          user_id: args[:user_id],
          timestamp: Time.current
        )

        {
          success: true,
          event_id: event.id,
          event_name: event.name,
          timestamp: event.timestamp.iso8601
        }
      end
    end
  end
end
