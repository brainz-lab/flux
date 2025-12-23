# frozen_string_literal: true

module Mcp
  module Tools
    class Base
      DESCRIPTION = "Base tool"
      SCHEMA = {
        type: "object",
        properties: {}
      }.freeze

      def initialize(project)
        @project = project
      end

      def call(args)
        raise NotImplementedError
      end

      protected

      def parse_since(value)
        case value
        when /^(\d+)m$/ then $1.to_i.minutes.ago
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        when /^(\d+)w$/ then $1.to_i.weeks.ago
        else 24.hours.ago
        end
      end
    end
  end
end
