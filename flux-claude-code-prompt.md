# Flux - Custom Metrics & Events

## The Vision

**Flux** is your custom metrics and events platform. Track anything, alert on patterns, build dashboards.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                              FLUX                                            │
│                    "Track anything, see everything"                         │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   EVENTS                    METRICS                 PATTERNS        │   │
│   │   ────────                  ───────                 ────────        │   │
│   │   user.signup               response_time           Anomalies       │   │
│   │   order.completed           queue_depth             Trends          │   │
│   │   payment.failed            active_users            Correlations    │   │
│   │   feature.used              revenue                 Forecasts       │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         DASHBOARDS                                   │   │
│   │                                                                      │   │
│   │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│   │   │ Revenue  │  │  Users   │  │  Errors  │  │  Perf    │          │   │
│   │   │  Today   │  │  Online  │  │  Rate    │  │  P95     │          │   │
│   │   │ $12,450  │  │   234    │  │  0.02%   │  │  145ms   │          │   │
│   │   └──────────┘  └──────────┘  └──────────┘  └──────────┘          │   │
│   │                                                                      │   │
│   │   ┌─────────────────────────────────────────────────────────────┐  │   │
│   │   │                    Orders per Hour                          │  │   │
│   │   │     ▄▄                                                      │  │   │
│   │   │    ████  ▄▄                                    ▄▄           │  │   │
│   │   │   ██████████ ▄▄▄▄                           ▄▄████          │  │   │
│   │   │  ████████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄████████          │  │   │
│   │   └─────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Integrates with: Signal (alerts) │ Pulse (APM) │ Recall (logs)           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Events (Discrete occurrences)

```ruby
# Track business events
BrainzLab::Flux.track("user.signup", {
  user_id: user.id,
  plan: "pro",
  source: "google_ads",
  value: 29.99
})

BrainzLab::Flux.track("order.completed", {
  order_id: order.id,
  total: 149.99,
  items: 3,
  customer_type: "returning"
})

BrainzLab::Flux.track("feature.used", {
  feature: "export_pdf",
  user_id: current_user.id,
  duration_ms: 1234
})
```

### 2. Metrics (Continuous measurements)

```ruby
# Gauges - Current value
BrainzLab::Flux.gauge("users.online", 234)
BrainzLab::Flux.gauge("queue.depth", Sidekiq::Queue.new.size)
BrainzLab::Flux.gauge("cache.hit_rate", 0.95)

# Counters - Incrementing values
BrainzLab::Flux.increment("api.requests")
BrainzLab::Flux.increment("emails.sent", 5)
BrainzLab::Flux.decrement("inventory.widgets")

# Distributions - Statistical values
BrainzLab::Flux.distribution("response_time", 145.2)
BrainzLab::Flux.distribution("order_value", 89.99)

# Sets - Unique counts
BrainzLab::Flux.set("daily_active_users", user.id)
BrainzLab::Flux.set("unique_ips", request.remote_ip)
```

### 3. Patterns (AI-detected)

```ruby
# Automatic pattern detection:
# - Anomaly detection (sudden spikes/drops)
# - Trend analysis (gradual changes)
# - Correlations (A affects B)
# - Seasonality (hourly/daily/weekly patterns)
# - Forecasting (predict next values)
```

---

## Database Schema

```ruby
# db/migrate/001_create_events.rb

class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    # Events table (TimescaleDB hypertable)
    create_table :events, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :name, null: false              # "user.signup", "order.completed"
      t.datetime :timestamp, null: false
      
      # Dimensions (for grouping/filtering)
      t.string :environment
      t.string :service
      t.string :host
      
      # Event data
      t.jsonb :properties, default: {}         # Custom properties
      t.jsonb :tags, default: {}               # Key-value tags
      
      # User context
      t.string :user_id
      t.string :session_id
      
      # Value (for aggregations)
      t.decimal :value                         # Optional numeric value
      
      t.datetime :created_at, null: false
    end

    # Convert to hypertable
    execute "SELECT create_hypertable('events', 'timestamp');"
    
    add_index :events, [:project_id, :name, :timestamp]
    add_index :events, [:project_id, :timestamp]
    add_index :events, :user_id
    execute "CREATE INDEX idx_events_properties ON events USING GIN (properties jsonb_path_ops);"
  end
end

# db/migrate/002_create_metrics.rb

class CreateMetrics < ActiveRecord::Migration[8.0]
  def change
    # Metric definitions
    create_table :metric_definitions, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :name, null: false              # "response_time", "queue.depth"
      t.string :display_name
      t.text :description
      
      t.string :metric_type, null: false       # gauge, counter, distribution, set
      t.string :unit                           # ms, bytes, requests, usd
      
      t.jsonb :tags_schema, default: {}        # Expected tags
      t.jsonb :aggregations, default: []       # Pre-compute these: avg, p95, sum
      
      t.timestamps
      
      t.index [:project_id, :name], unique: true
    end

    # Metric data points (TimescaleDB hypertable)
    create_table :metric_points, id: false do |t|
      t.references :project, type: :uuid, null: false
      t.string :metric_name, null: false
      t.datetime :timestamp, null: false
      
      # Values
      t.float :value                           # For gauge/counter
      t.float :sum                             # For distribution
      t.float :count                           # For distribution
      t.float :min                             # For distribution
      t.float :max                             # For distribution
      t.float :p50                             # Percentiles
      t.float :p95
      t.float :p99
      
      # For sets (cardinality)
      t.integer :cardinality
      t.binary :hll_data                       # HyperLogLog for unique counts
      
      # Dimensions
      t.jsonb :tags, default: {}
    end

    execute "SELECT create_hypertable('metric_points', 'timestamp');"
    
    add_index :metric_points, [:project_id, :metric_name, :timestamp]
    execute "CREATE INDEX idx_metric_points_tags ON metric_points USING GIN (tags jsonb_path_ops);"
    
    # Compression for old data
    execute <<-SQL
      SELECT add_compression_policy('metric_points', INTERVAL '7 days');
    SQL
    
    # Retention policy
    execute <<-SQL
      SELECT add_retention_policy('metric_points', INTERVAL '90 days');
    SQL
  end
end

# db/migrate/003_create_aggregated_metrics.rb

class CreateAggregatedMetrics < ActiveRecord::Migration[8.0]
  def change
    # Pre-aggregated metrics (1m, 5m, 1h, 1d buckets)
    create_table :aggregated_metrics, id: false do |t|
      t.references :project, type: :uuid, null: false
      t.string :metric_name, null: false
      t.string :bucket_size, null: false       # 1m, 5m, 1h, 1d
      t.datetime :bucket_time, null: false
      
      t.float :sum
      t.float :count
      t.float :avg
      t.float :min
      t.float :max
      t.float :p50
      t.float :p95
      t.float :p99
      
      t.jsonb :tags, default: {}
    end

    execute "SELECT create_hypertable('aggregated_metrics', 'bucket_time');"
    
    add_index :aggregated_metrics, [:project_id, :metric_name, :bucket_size, :bucket_time]
    
    # Continuous aggregates for fast queries
    execute <<-SQL
      CREATE MATERIALIZED VIEW metrics_1h
      WITH (timescaledb.continuous) AS
      SELECT
        project_id,
        metric_name,
        time_bucket('1 hour', timestamp) AS bucket,
        tags,
        avg(value) as avg,
        sum(value) as sum,
        count(*) as count,
        min(value) as min,
        max(value) as max,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY value) as p50,
        percentile_cont(0.95) WITHIN GROUP (ORDER BY value) as p95,
        percentile_cont(0.99) WITHIN GROUP (ORDER BY value) as p99
      FROM metric_points
      GROUP BY project_id, metric_name, bucket, tags;
    SQL
  end
end

# db/migrate/004_create_dashboards.rb

class CreateDashboards < ActiveRecord::Migration[8.0]
  def change
    create_table :dashboards, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :is_default, default: false
      t.boolean :is_public, default: false     # Public status page
      
      t.jsonb :layout, default: {}             # Grid layout
      t.jsonb :settings, default: {}
      
      t.timestamps
      
      t.index [:project_id, :slug], unique: true
    end

    create_table :widgets, id: :uuid do |t|
      t.references :dashboard, type: :uuid, null: false, foreign_key: true
      
      t.string :title
      t.string :widget_type, null: false
      # Types: number, graph, bar, pie, table, heatmap, list, markdown
      
      t.jsonb :query, default: {}
      # {
      #   source: "metrics",           # metrics, events, pulse, reflex
      #   metric: "response_time",
      #   aggregation: "p95",
      #   filters: { environment: "production" },
      #   group_by: ["endpoint"],
      #   time_range: "24h"
      # }
      
      t.jsonb :display, default: {}
      # {
      #   color: "#3B82F6",
      #   format: "duration",          # number, duration, bytes, currency
      #   thresholds: { warning: 200, critical: 500 }
      # }
      
      t.jsonb :position, default: {}
      # { x: 0, y: 0, w: 4, h: 2 }
      
      t.timestamps
    end
  end
end

# db/migrate/005_create_anomalies.rb

class CreateAnomalies < ActiveRecord::Migration[8.0]
  def change
    create_table :anomalies, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :source, null: false            # metric, event
      t.string :source_name, null: false       # metric/event name
      
      t.string :anomaly_type, null: false      # spike, drop, trend, seasonality
      t.string :severity, default: 'info'      # info, warning, critical
      
      t.float :expected_value
      t.float :actual_value
      t.float :deviation_percent
      
      t.datetime :detected_at, null: false
      t.datetime :started_at
      t.datetime :ended_at
      
      t.jsonb :context, default: {}
      t.boolean :acknowledged, default: false
      
      t.timestamps
      
      t.index [:project_id, :detected_at]
      t.index [:project_id, :source_name]
    end
  end
end
```

---

## API Endpoints

```ruby
# config/routes.rb

namespace :api do
  namespace :v1 do
    # Events
    post 'events', to: 'events#create'
    post 'events/batch', to: 'events#batch'
    get 'events', to: 'events#index'
    get 'events/count', to: 'events#count'
    get 'events/stats', to: 'events#stats'
    
    # Metrics
    post 'metrics', to: 'metrics#create'
    post 'metrics/batch', to: 'metrics#batch'
    get 'metrics', to: 'metrics#index'
    get 'metrics/:name', to: 'metrics#show'
    get 'metrics/:name/query', to: 'metrics#query'
    
    # Dashboards
    resources :dashboards do
      resources :widgets
    end
    
    # Anomalies
    get 'anomalies', to: 'anomalies#index'
    post 'anomalies/:id/acknowledge', to: 'anomalies#acknowledge'
  end
end
```

```ruby
# app/controllers/api/v1/events_controller.rb

module Api
  module V1
    class EventsController < BaseController
      def create
        event = Event.create!(
          project: @project,
          name: params[:name],
          timestamp: params[:timestamp] || Time.current,
          properties: params[:properties] || {},
          tags: params[:tags] || {},
          user_id: params[:user_id],
          value: params[:value],
          environment: params[:environment],
          service: params[:service]
        )
        
        # Check for anomalies asynchronously
        AnomalyDetectionJob.perform_later(event.id)
        
        render json: { id: event.id }, status: :created
      end
      
      def batch
        events = params[:events] || params[:_json] || []
        
        Event.insert_all(events.map { |e| build_event(e) })
        
        render json: { ingested: events.size }, status: :created
      end
      
      def index
        query = EventQuery.new(@project, query_params)
        events = query.execute
        
        render json: {
          events: events,
          total: query.total,
          query: query_params
        }
      end
      
      def count
        query = EventQuery.new(@project, query_params)
        
        render json: {
          count: query.count,
          query: query_params
        }
      end
      
      def stats
        query = EventQuery.new(@project, query_params)
        
        render json: {
          stats: query.stats,
          by_name: query.group_by_name,
          by_hour: query.group_by_hour,
          query: query_params
        }
      end
    end
  end
end

# app/controllers/api/v1/metrics_controller.rb

module Api
  module V1
    class MetricsController < BaseController
      def create
        case params[:type]
        when 'gauge'
          track_gauge(params[:name], params[:value], params[:tags])
        when 'counter'
          track_counter(params[:name], params[:value] || 1, params[:tags])
        when 'distribution'
          track_distribution(params[:name], params[:value], params[:tags])
        when 'set'
          track_set(params[:name], params[:value], params[:tags])
        end
        
        render json: { success: true }, status: :created
      end
      
      def query
        metric = params[:name]
        
        result = MetricQuery.new(@project, metric, query_params).execute
        
        render json: {
          metric: metric,
          data: result[:data],
          aggregation: result[:aggregation],
          time_range: query_params[:time_range]
        }
      end
      
      private
      
      def track_gauge(name, value, tags = {})
        MetricPoint.create!(
          project: @project,
          metric_name: name,
          timestamp: Time.current,
          value: value,
          tags: tags
        )
      end
      
      def track_distribution(name, value, tags = {})
        # Aggregate in memory, flush periodically
        MetricAggregator.add(
          project_id: @project.id,
          metric_name: name,
          value: value,
          tags: tags
        )
      end
    end
  end
end
```

---

## SDK Integration

```ruby
# lib/brainzlab/flux.rb

module BrainzLab
  module Flux
    class << self
      # === EVENTS ===
      
      def track(name, properties = {})
        event = {
          name: name,
          timestamp: Time.now.utc.iso8601(3),
          properties: properties.except(:user_id, :value, :tags),
          user_id: properties[:user_id],
          value: properties[:value],
          tags: properties[:tags] || {},
          environment: BrainzLab.config.environment,
          service: BrainzLab.config.service
        }
        
        buffer.add(:event, event)
      end
      
      # === METRICS ===
      
      # Gauge: Current value (overwrites)
      def gauge(name, value, tags: {})
        metric = {
          type: 'gauge',
          name: name,
          value: value,
          tags: tags,
          timestamp: Time.now.utc.iso8601(3)
        }
        
        buffer.add(:metric, metric)
      end
      
      # Counter: Increment/decrement
      def increment(name, value = 1, tags: {})
        metric = {
          type: 'counter',
          name: name,
          value: value,
          tags: tags,
          timestamp: Time.now.utc.iso8601(3)
        }
        
        buffer.add(:metric, metric)
      end
      
      def decrement(name, value = 1, tags: {})
        increment(name, -value, tags: tags)
      end
      
      # Distribution: Statistical aggregation
      def distribution(name, value, tags: {})
        metric = {
          type: 'distribution',
          name: name,
          value: value,
          tags: tags,
          timestamp: Time.now.utc.iso8601(3)
        }
        
        buffer.add(:metric, metric)
      end
      
      # Set: Unique count
      def set(name, value, tags: {})
        metric = {
          type: 'set',
          name: name,
          value: value.to_s,  # Convert to string for HLL
          tags: tags,
          timestamp: Time.now.utc.iso8601(3)
        }
        
        buffer.add(:metric, metric)
      end
      
      # === CONVENIENCE METHODS ===
      
      # Time a block and record distribution
      def measure(name, tags: {}, &block)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = block.call
        duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        
        distribution(name, duration, tags: tags.merge(unit: 'ms'))
        
        result
      end
      
      # Track with user context
      def track_for_user(user, name, properties = {})
        track(name, properties.merge(
          user_id: user.respond_to?(:id) ? user.id.to_s : user.to_s
        ))
      end
      
      private
      
      def buffer
        @buffer ||= FluxBuffer.new
      end
    end
    
    class FluxBuffer
      def initialize
        @events = []
        @metrics = []
        @mutex = Mutex.new
        @last_flush = Time.now
        
        start_flush_thread
      end
      
      def add(type, data)
        @mutex.synchronize do
          case type
          when :event then @events << data
          when :metric then @metrics << data
          end
          
          flush! if should_flush?
        end
      end
      
      def flush!
        events, @events = @events, []
        metrics, @metrics = @metrics, []
        @last_flush = Time.now
        
        send_batch(events, metrics) if events.any? || metrics.any?
      end
      
      private
      
      def should_flush?
        @events.size >= 100 || 
        @metrics.size >= 100 || 
        Time.now - @last_flush >= 5
      end
      
      def send_batch(events, metrics)
        Thread.new do
          client.post('/api/v1/flux/batch', {
            events: events,
            metrics: metrics
          })
        end
      end
      
      def start_flush_thread
        Thread.new do
          loop do
            sleep 5
            @mutex.synchronize { flush! }
          end
        end
      end
    end
  end
end
```

---

## MCP Tools

```ruby
# app/services/mcp/tools/flux_*.rb

module Mcp
  module Tools
    class FluxTrack < Base
      DESCRIPTION = "Track a custom event"
      SCHEMA = {
        type: "object",
        properties: {
          name: { type: "string", description: "Event name (e.g., 'user.signup')" },
          properties: { type: "object", description: "Event properties" },
          value: { type: "number", description: "Optional numeric value" }
        },
        required: ["name"]
      }
      
      def call(args)
        Event.create!(
          project: @project,
          name: args[:name],
          properties: args[:properties] || {},
          value: args[:value],
          timestamp: Time.current
        )
        
        { success: true, event: args[:name] }
      end
    end
    
    class FluxQuery < Base
      DESCRIPTION = "Query events with filters and aggregations"
      SCHEMA = {
        type: "object",
        properties: {
          name: { type: "string", description: "Event name to query" },
          since: { type: "string", description: "Time range (1h, 24h, 7d)" },
          group_by: { type: "string", description: "Group by property" },
          aggregation: { type: "string", enum: ["count", "sum", "avg"] }
        },
        required: ["name"]
      }
      
      def call(args)
        query = EventQuery.new(@project, args)
        
        {
          name: args[:name],
          data: query.execute,
          total: query.count
        }
      end
    end
    
    class FluxMetric < Base
      DESCRIPTION = "Get metric values over time"
      SCHEMA = {
        type: "object",
        properties: {
          name: { type: "string", description: "Metric name" },
          aggregation: { type: "string", enum: ["avg", "sum", "min", "max", "p95", "p99"] },
          since: { type: "string", description: "Time range" },
          group_by: { type: "array", items: { type: "string" } }
        },
        required: ["name"]
      }
      
      def call(args)
        query = MetricQuery.new(@project, args[:name], args)
        
        {
          metric: args[:name],
          aggregation: args[:aggregation] || 'avg',
          data: query.execute
        }
      end
    end
    
    class FluxDashboard < Base
      DESCRIPTION = "Get dashboard data with all widgets"
      SCHEMA = {
        type: "object",
        properties: {
          dashboard: { type: "string", description: "Dashboard slug or ID" }
        },
        required: ["dashboard"]
      }
      
      def call(args)
        dashboard = @project.dashboards.find_by!(slug: args[:dashboard])
        
        {
          name: dashboard.name,
          widgets: dashboard.widgets.map { |w| execute_widget(w) }
        }
      end
    end
    
    class FluxAnomalies < Base
      DESCRIPTION = "List detected anomalies"
      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "24h" },
          severity: { type: "string", enum: ["info", "warning", "critical"] }
        }
      }
      
      def call(args)
        anomalies = @project.anomalies
          .where('detected_at >= ?', parse_time(args[:since] || '24h'))
          .order(detected_at: :desc)
        
        anomalies = anomalies.where(severity: args[:severity]) if args[:severity]
        
        { anomalies: anomalies.limit(50).as_json }
      end
    end
  end
end
```

---

## Anomaly Detection

```ruby
# app/services/anomaly_detector.rb

class AnomalyDetector
  def initialize(project)
    @project = project
  end
  
  def detect_for_metric(metric_name, since: 1.hour.ago)
    # Get recent data
    recent = get_metric_data(metric_name, since: since)
    
    # Get baseline (same time yesterday, last week)
    baseline_yesterday = get_metric_data(metric_name, since: since - 1.day, until_time: Time.current - 1.day)
    baseline_week = get_metric_data(metric_name, since: since - 1.week, until_time: Time.current - 1.week)
    
    # Calculate expected value
    expected = calculate_expected(baseline_yesterday, baseline_week)
    actual = recent.average(:value)
    
    # Check for anomaly
    deviation = ((actual - expected) / expected * 100).abs
    
    if deviation > threshold_for(metric_name)
      create_anomaly(
        source: 'metric',
        source_name: metric_name,
        anomaly_type: actual > expected ? 'spike' : 'drop',
        expected_value: expected,
        actual_value: actual,
        deviation_percent: deviation
      )
    end
  end
  
  def detect_for_event(event_name, since: 1.hour.ago)
    # Count events in period
    recent_count = @project.events.where(name: event_name).where('timestamp >= ?', since).count
    
    # Get baseline
    baseline_count = @project.events
      .where(name: event_name)
      .where('timestamp >= ? AND timestamp < ?', since - 1.day, Time.current - 1.day)
      .count
    
    # Detect sudden spike or drop
    if baseline_count > 0
      ratio = recent_count.to_f / baseline_count
      
      if ratio > 3.0  # 3x spike
        create_anomaly(
          source: 'event',
          source_name: event_name,
          anomaly_type: 'spike',
          expected_value: baseline_count,
          actual_value: recent_count,
          deviation_percent: (ratio - 1) * 100
        )
      elsif ratio < 0.3  # 70% drop
        create_anomaly(
          source: 'event',
          source_name: event_name,
          anomaly_type: 'drop',
          expected_value: baseline_count,
          actual_value: recent_count,
          deviation_percent: (1 - ratio) * 100
        )
      end
    end
  end
  
  private
  
  def threshold_for(metric_name)
    # Different thresholds for different metrics
    case metric_name
    when /error/, /failed/ then 50   # 50% change is significant
    when /response_time/ then 30     # 30% change
    else 100                          # Default: 100% (2x) change
    end
  end
  
  def create_anomaly(attrs)
    Anomaly.create!(
      project: @project,
      detected_at: Time.current,
      severity: calculate_severity(attrs[:deviation_percent]),
      **attrs
    )
  end
  
  def calculate_severity(deviation)
    case deviation
    when 0..50 then 'info'
    when 50..100 then 'warning'
    else 'critical'
    end
  end
end
```

---

## Dashboard Builder

```ruby
# app/services/dashboard_builder.rb

class DashboardBuilder
  WIDGET_TYPES = {
    number: NumberWidget,
    graph: GraphWidget,
    bar: BarWidget,
    pie: PieWidget,
    table: TableWidget,
    heatmap: HeatmapWidget
  }.freeze
  
  def initialize(dashboard)
    @dashboard = dashboard
  end
  
  def add_widget(type, title, query, position: {})
    widget = @dashboard.widgets.create!(
      widget_type: type,
      title: title,
      query: query,
      position: position
    )
    
    widget
  end
  
  def execute_all
    @dashboard.widgets.map do |widget|
      execute_widget(widget)
    end
  end
  
  def execute_widget(widget)
    widget_class = WIDGET_TYPES[widget.widget_type.to_sym]
    widget_class.new(@dashboard.project, widget).execute
  end
end

class NumberWidget
  def execute
    value = case query[:source]
    when 'metrics'
      MetricQuery.new(@project, query[:metric], query).latest
    when 'events'
      EventQuery.new(@project, query).count
    when 'pulse'
      PulseQuery.new(@project, query).apdex
    end
    
    {
      type: 'number',
      value: value,
      formatted: format_value(value),
      change: calculate_change(value)
    }
  end
end

class GraphWidget
  def execute
    data = case query[:source]
    when 'metrics'
      MetricQuery.new(@project, query[:metric], query).time_series
    when 'events'
      EventQuery.new(@project, query).time_series
    end
    
    {
      type: 'graph',
      data: data,
      x_axis: 'time',
      y_axis: query[:aggregation] || 'value'
    }
  end
end
```

---

## Usage Examples

```ruby
# Track business events
BrainzLab::Flux.track("user.signup", {
  user_id: user.id,
  plan: "pro",
  source: params[:utm_source],
  value: 29.99  # MRR value
})

BrainzLab::Flux.track("order.completed", {
  order_id: order.id,
  total: order.total,
  items: order.items.count,
  payment_method: order.payment_method
})

BrainzLab::Flux.track("feature.used", {
  feature: "export_pdf",
  user_id: current_user.id
})

# Track metrics
BrainzLab::Flux.gauge("users.online", User.online.count)
BrainzLab::Flux.gauge("queue.sidekiq", Sidekiq::Queue.new.size)

BrainzLab::Flux.increment("api.requests", tags: { endpoint: "/api/orders" })
BrainzLab::Flux.increment("emails.sent", 5)

BrainzLab::Flux.distribution("order_value", order.total, tags: { country: order.country })

BrainzLab::Flux.set("daily_active_users", current_user.id)

# Time operations
BrainzLab::Flux.measure("pdf.generate", tags: { pages: 10 }) do
  generate_pdf(document)
end

# In controllers
class OrdersController < ApplicationController
  def create
    order = Order.create!(order_params)
    
    BrainzLab::Flux.track("order.created", {
      order_id: order.id,
      total: order.total,
      user_id: current_user.id,
      items: order.items.count
    })
    
    BrainzLab::Flux.increment("orders.count")
    BrainzLab::Flux.distribution("order.value", order.total)
  end
end

# Background jobs
class RevenueMetricsJob < ApplicationJob
  def perform
    revenue = Order.where('created_at >= ?', 1.day.ago).sum(:total)
    
    BrainzLab::Flux.gauge("revenue.daily", revenue, tags: { currency: "usd" })
    BrainzLab::Flux.gauge("orders.daily", Order.where('created_at >= ?', 1.day.ago).count)
  end
end
```

---

## Integration with Other Products

```ruby
# Signal: Alert on Flux metrics/events
# alert_rule.yml
{
  source: "flux",
  metric: "orders.count",
  condition: "< 10",       # Less than 10 orders per hour
  window: "1h",
  severity: "critical",
  notify: ["slack-ops"]
}

# Pulse: Flux metrics appear in APM dashboard
# Auto-correlate slow requests with Flux events

# Recall: Link Flux events to log entries
# Same request_id/session_id for correlation
```

---

## Summary

### Flux Provides

| Feature | Description |
|---------|-------------|
| **Events** | Track discrete occurrences (signups, orders, etc.) |
| **Metrics** | Track continuous values (gauges, counters, distributions) |
| **Dashboards** | Custom dashboards with widgets |
| **Anomalies** | AI-detected patterns and deviations |
| **Correlations** | Link events/metrics to traces and logs |

### MCP Tools

| Tool | Description |
|------|-------------|
| `flux_track` | Track a custom event |
| `flux_query` | Query events with filters |
| `flux_metric` | Query metric time series |
| `flux_dashboard` | Get dashboard data |
| `flux_anomalies` | List detected anomalies |

### SDK Methods

```ruby
BrainzLab::Flux.track(name, properties)      # Events
BrainzLab::Flux.gauge(name, value)           # Current value
BrainzLab::Flux.increment(name, value)       # Counter
BrainzLab::Flux.distribution(name, value)    # Statistical
BrainzLab::Flux.set(name, value)             # Unique count
BrainzLab::Flux.measure(name) { }            # Time block
```

---

## Build Order

```
PARALLEL BUILD:

Platform ─────────────┐
                      ├──▶ Integration ──▶ Launch
Signal ───────────────┤
                      │
Flux ─────────────────┘

Week 1-2: All three in parallel
Week 3: Integration + testing
Week 4: Launch
```

---

*Flux = Your data, your way! 📊*
