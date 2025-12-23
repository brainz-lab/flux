# frozen_string_literal: true

module Dashboard
  class EventsController < BaseController
    def index
      @since = parse_since(params[:since] || "24h")
      @events = current_project.events.since(@since).recent

      @events = @events.by_name(params[:name]) if params[:name].present?
      @events = @events.where(user_id: params[:user_id]) if params[:user_id].present?

      @events = @events.limit(100)

      @event_counts = current_project.events.since(@since).group(:name).count
                                     .sort_by { |_, v| -v }.to_h
    end

    def show
      @event = current_project.events.find(params[:id])
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
