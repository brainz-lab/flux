# frozen_string_literal: true

class EventQuery
  attr_reader :project, :params

  def initialize(project, params = {})
    @project = project
    @params = params.with_indifferent_access
  end

  def execute
    scope = base_scope
    scope = apply_filters(scope)
    scope = apply_ordering(scope)
    scope = apply_pagination(scope)
    scope
  end

  def count
    scope = base_scope
    scope = apply_filters(scope)
    scope.count
  end

  def total
    @total ||= count
  end

  def stats
    scope = base_scope
    scope = apply_filters(scope)

    {
      total: scope.count,
      unique_names: scope.distinct.count(:name),
      unique_users: scope.where.not(user_id: nil).distinct.count(:user_id),
      with_value: scope.where.not(value: nil).count,
      avg_value: scope.where.not(value: nil).average(:value)&.round(2),
      sum_value: scope.where.not(value: nil).sum(:value)&.round(2)
    }
  end

  def group_by_name
    scope = base_scope
    scope = apply_filters(scope)
    scope.group(:name).count.sort_by { |_, v| -v }.first(20).to_h
  end

  def group_by_hour
    scope = base_scope
    scope = apply_filters(scope)
    scope.group_by_hour(:timestamp).count
  end

  def time_series(interval: "1 hour")
    scope = base_scope
    scope = apply_filters(scope)

    scope
      .select("time_bucket('#{interval}', timestamp) AS bucket, COUNT(*) as count")
      .group("bucket")
      .order("bucket")
      .map { |r| { time: r.bucket, count: r.count } }
  end

  private

  def base_scope
    project.events
  end

  def apply_filters(scope)
    # Name filter
    scope = scope.where(name: params[:name]) if params[:name].present?
    scope = scope.where("name LIKE ?", "%#{params[:name_contains]}%") if params[:name_contains].present?

    # Time filters
    scope = scope.since(parse_time(params[:since])) if params[:since].present?
    scope = scope.until_time(Time.parse(params[:until])) if params[:until].present?

    # User filters
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
    scope = scope.where(session_id: params[:session_id]) if params[:session_id].present?

    # Environment filters
    scope = scope.where(environment: params[:environment]) if params[:environment].present?
    scope = scope.where(service: params[:service]) if params[:service].present?
    scope = scope.where(host: params[:host]) if params[:host].present?

    # Property/tag filters
    if params[:properties].present?
      params[:properties].each do |key, value|
        scope = scope.where("properties->>? = ?", key, value.to_s)
      end
    end

    if params[:tags].present?
      params[:tags].each do |key, value|
        scope = scope.where("tags->>? = ?", key, value.to_s)
      end
    end

    # Value filters
    scope = scope.where.not(value: nil) if params[:has_value] == "true"
    scope = scope.where("value >= ?", params[:min_value]) if params[:min_value].present?
    scope = scope.where("value <= ?", params[:max_value]) if params[:max_value].present?

    scope
  end

  def apply_ordering(scope)
    order = params[:order] || "desc"
    sort = params[:sort] || "timestamp"

    case sort
    when "timestamp"
      scope.order(timestamp: order.to_sym)
    when "name"
      scope.order(name: order.to_sym)
    when "value"
      scope.order(value: order.to_sym)
    else
      scope.order(timestamp: :desc)
    end
  end

  def apply_pagination(scope)
    limit = (params[:limit] || 100).to_i.clamp(1, 1000)
    offset = (params[:offset] || 0).to_i

    scope.limit(limit).offset(offset)
  end

  def parse_time(value)
    case value
    when /^(\d+)m$/ then $1.to_i.minutes.ago
    when /^(\d+)h$/ then $1.to_i.hours.ago
    when /^(\d+)d$/ then $1.to_i.days.ago
    when /^(\d+)w$/ then $1.to_i.weeks.ago
    else
      begin
        Time.parse(value)
      rescue
        24.hours.ago
      end
    end
  end
end
