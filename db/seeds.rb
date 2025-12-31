# frozen_string_literal: true

# Flux seed data - demonstrates all dashboard capabilities

puts "Seeding Flux..."

# Find or create project for the platform project
project = Project.find_or_create_by!(platform_project_id: "4d6331d5-c8b1-4764-9b5a-a13c740798ec") do |p|
  p.name = "Demo Application"
  p.description = "Sample application demonstrating Flux metrics and events"
  p.environment = "production"
end

puts "Project: #{project.name} (#{project.id})"
puts "  API Key: #{project.api_key}"
puts "  Ingest Key: #{project.ingest_key}"

# Clear existing data for this project (for re-seeding)
project.events.delete_all
project.metric_points.delete_all
project.metric_definitions.destroy_all
project.flux_dashboards.destroy_all
project.anomalies.delete_all

# ============================================================================
# METRIC DEFINITIONS
# ============================================================================
puts "\nCreating metric definitions..."

metrics = {
  # Gauges - current values
  "users.online" => { type: "gauge", unit: "users", display: "Online Users", desc: "Currently connected users" },
  "queue.depth" => { type: "gauge", unit: "jobs", display: "Queue Depth", desc: "Jobs waiting in queue" },
  "memory.usage" => { type: "gauge", unit: "MB", display: "Memory Usage", desc: "Current memory consumption" },
  "cpu.utilization" => { type: "gauge", unit: "%", display: "CPU Utilization", desc: "Current CPU usage percentage" },
  "disk.usage" => { type: "gauge", unit: "GB", display: "Disk Usage", desc: "Disk space used" },
  "cache.hit_rate" => { type: "gauge", unit: "%", display: "Cache Hit Rate", desc: "Cache efficiency" },

  # Counters - incrementing values
  "api.requests" => { type: "counter", unit: "requests", display: "API Requests", desc: "Total API requests" },
  "emails.sent" => { type: "counter", unit: "emails", display: "Emails Sent", desc: "Outbound emails" },
  "errors.total" => { type: "counter", unit: "errors", display: "Total Errors", desc: "Application errors" },
  "signups.total" => { type: "counter", unit: "signups", display: "Total Signups", desc: "User registrations" },
  "payments.processed" => { type: "counter", unit: "payments", display: "Payments Processed", desc: "Successful payments" },

  # Distributions - statistical aggregation
  "response_time" => { type: "distribution", unit: "ms", display: "Response Time", desc: "API response latency" },
  "order_value" => { type: "distribution", unit: "USD", display: "Order Value", desc: "Transaction amounts" },
  "page_load_time" => { type: "distribution", unit: "ms", display: "Page Load Time", desc: "Frontend performance" },
  "db.query_time" => { type: "distribution", unit: "ms", display: "DB Query Time", desc: "Database latency" },

  # Sets - unique counts
  "daily_active_users" => { type: "set", unit: "users", display: "Daily Active Users", desc: "Unique users today" },
  "unique_pages_viewed" => { type: "set", unit: "pages", display: "Unique Pages", desc: "Distinct page views" }
}

metric_defs = {}
metrics.each do |name, config|
  metric_defs[name] = MetricDefinition.create!(
    project: project,
    name: name,
    display_name: config[:display],
    description: config[:desc],
    metric_type: config[:type],
    unit: config[:unit]
  )
  print "."
end
puts " #{metric_defs.count} metrics"

# ============================================================================
# METRIC POINTS (Time Series Data)
# ============================================================================
puts "\nGenerating metric points (last 7 days)..."

now = Time.current
endpoints = [ "/api/users", "/api/orders", "/api/products", "/api/payments", "/api/search" ]
environments = [ "production", "staging" ]

# Generate 7 days of data at 5-minute intervals
# Use raw SQL for TimescaleDB hypertables (no standard primary key)
points_count = 0
sql_values = []

def quote_value(val)
  return "NULL" if val.nil?
  return "'#{val.to_json.gsub("'", "''")}'" if val.is_a?(Hash)
  return "'#{val.iso8601}'" if val.is_a?(Time)
  return "'#{val}'" if val.is_a?(String)
  val.to_s
end

(7.days.ago.to_i..now.to_i).step(5.minutes.to_i) do |ts|
  timestamp = Time.at(ts)
  hour = timestamp.hour

  # Simulate daily patterns (more traffic during business hours)
  traffic_multiplier = case hour
  when 9..17 then 1.5  # Business hours
  when 18..22 then 1.2 # Evening
  when 23, 0..5 then 0.4 # Night
  else 0.8
  end

  # Add some randomness
  noise = rand(0.8..1.2)

  # Gauge metrics (current values)
  sql_values << "('#{project.id}', 'users.online', '#{timestamp.iso8601}', #{(150 * traffic_multiplier * noise).round}, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{\"environment\":\"production\"}')"
  sql_values << "('#{project.id}', 'queue.depth', '#{timestamp.iso8601}', #{(rand(5..50) * traffic_multiplier).round}, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{\"environment\":\"production\"}')"
  sql_values << "('#{project.id}', 'memory.usage', '#{timestamp.iso8601}', #{(512 + rand(-50..100) + (hour * 2)).round}, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{\"host\":\"web-#{rand(1..3)}\"}')"
  sql_values << "('#{project.id}', 'cpu.utilization', '#{timestamp.iso8601}', #{(30 * traffic_multiplier + rand(-10..20)).clamp(5, 95).round}, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{\"host\":\"web-#{rand(1..3)}\"}')"
  sql_values << "('#{project.id}', 'cache.hit_rate', '#{timestamp.iso8601}', #{(85 + rand(-5..10)).clamp(70, 99).round}, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{}')"

  # Distribution metrics (with percentiles)
  base_response_time = 80 * (1.0 / traffic_multiplier) # Slower when busier
  endpoints.each do |endpoint|
    val = (base_response_time + rand(-20..40)).round(1)
    p50 = (base_response_time * 0.8 + rand(-10..10)).round(1)
    p95 = (base_response_time * 2.5 + rand(-20..50)).round(1)
    p99 = (base_response_time * 4.0 + rand(-30..80)).round(1)
    cnt = (100 * traffic_multiplier * noise).round
    tags = { endpoint: endpoint, environment: "production" }.to_json.gsub("'", "''")
    sql_values << "('#{project.id}', 'response_time', '#{timestamp.iso8601}', #{val}, NULL, #{cnt}, NULL, NULL, #{p50}, #{p95}, #{p99}, NULL, '#{tags}')"
  end

  val = (15 + rand(-5..20)).round(1)
  p50 = (12 + rand(-3..5)).round(1)
  p95 = (45 + rand(-10..30)).round(1)
  p99 = (80 + rand(-20..50)).round(1)
  cnt = (500 * traffic_multiplier).round
  sql_values << "('#{project.id}', 'db.query_time', '#{timestamp.iso8601}', #{val}, NULL, #{cnt}, NULL, NULL, #{p50}, #{p95}, #{p99}, NULL, '{\"database\":\"primary\"}')"

  # Counter metrics (cumulative)
  sql_values << "('#{project.id}', 'api.requests', '#{timestamp.iso8601}', #{(500 * traffic_multiplier * noise).round}, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{\"environment\":\"production\"}')"
  sql_values << "('#{project.id}', 'errors.total', '#{timestamp.iso8601}', #{(2 * traffic_multiplier * rand(0.5..2.0)).round}, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{\"environment\":\"production\"}')"

  # Order value distribution (e-commerce)
  if rand < 0.3 * traffic_multiplier  # Not every interval has orders
    val = rand(25..500).round(2)
    sum = rand(500..5000).round(2)
    cnt = rand(5..30)
    min = rand(10..50).round(2)
    max = rand(200..1000).round(2)
    sql_values << "('#{project.id}', 'order_value', '#{timestamp.iso8601}', #{val}, #{sum}, #{cnt}, #{min}, #{max}, NULL, NULL, NULL, NULL, '{\"currency\":\"USD\"}')"
  end

  points_count += 12

  # Insert in batches of 500 for performance
  if sql_values.size >= 500
    sql = "INSERT INTO metric_points (project_id, metric_name, timestamp, value, sum, count, min, max, p50, p95, p99, cardinality, tags) VALUES #{sql_values.join(', ')}"
    ActiveRecord::Base.connection.execute(sql)
    sql_values = []
    print "."
  end
end

# Insert remaining
if sql_values.any?
  sql = "INSERT INTO metric_points (project_id, metric_name, timestamp, value, sum, count, min, max, p50, p95, p99, cardinality, tags) VALUES #{sql_values.join(', ')}"
  ActiveRecord::Base.connection.execute(sql)
end
puts " #{points_count} points"

# ============================================================================
# EVENTS
# ============================================================================
puts "\nGenerating events (last 7 days)..."

event_types = [
  { name: "user.signup", properties: ->(i) { { plan: %w[free pro enterprise].sample, source: %w[organic google_ads facebook referral].sample } } },
  { name: "user.login", properties: ->(i) { { method: %w[email google github].sample, device: %w[desktop mobile tablet].sample } } },
  { name: "user.logout", properties: ->(i) { {} } },
  { name: "page.view", properties: ->(i) { { page: %w[/ /pricing /features /docs /blog].sample, referrer: %w[google direct twitter linkedin].sample } } },
  { name: "order.created", properties: ->(i) { { amount: rand(25..500).round(2), items: rand(1..5), coupon: [ nil, "SAVE10", "WELCOME20" ].sample } } },
  { name: "order.completed", properties: ->(i) { { amount: rand(25..500).round(2), payment_method: %w[card paypal apple_pay].sample } } },
  { name: "order.refunded", properties: ->(i) { { reason: %w[defective wrong_item changed_mind].sample } } },
  { name: "error.occurred", properties: ->(i) { { type: %w[ValidationError TimeoutError AuthError NotFoundError].sample, endpoint: endpoints.sample } } },
  { name: "email.sent", properties: ->(i) { { template: %w[welcome order_confirmation password_reset newsletter].sample } } },
  { name: "feature.used", properties: ->(i) { { feature: %w[dark_mode export import api_access webhooks].sample } } },
  { name: "search.performed", properties: ->(i) { { query_length: rand(2..30), results_count: rand(0..100) } } },
  { name: "payment.processed", properties: ->(i) { { amount: rand(9.99..999.99).round(2), currency: "USD", provider: %w[stripe paypal braintree].sample } } },
  { name: "subscription.upgraded", properties: ->(i) { { from: "free", to: %w[pro enterprise].sample } } },
  { name: "subscription.downgraded", properties: ->(i) { { from: "pro", to: "free" } } },
  { name: "api.rate_limited", properties: ->(i) { { endpoint: endpoints.sample, limit: 1000 } } }
]

events_count = 0
event_sql_values = []

(7.days.ago.to_i..now.to_i).step(1.minute.to_i) do |ts|
  timestamp = Time.at(ts)
  hour = timestamp.hour

  # Traffic pattern
  events_this_minute = case hour
  when 9..17 then rand(3..8)
  when 18..22 then rand(2..5)
  when 23, 0..5 then rand(0..2)
  else rand(1..4)
  end

  events_this_minute.times do
    event_type = event_types.sample
    user_id = "user_#{rand(1..500)}"
    event_ts = timestamp + rand(0..59).seconds
    props = event_type[:properties].call(events_count).to_json.gsub("'", "''")
    tags = '{"environment":"production","service":"web"}'
    session_id = "sess_#{Digest::MD5.hexdigest(user_id + timestamp.to_date.to_s)[0..8]}"
    val = event_type[:name].include?("order") ? rand(25..500).round(2) : "NULL"

    event_sql_values << "(gen_random_uuid(), '#{project.id}', '#{event_type[:name]}', '#{event_ts.iso8601}', NULL, NULL, NULL, '#{props}', '#{tags}', '#{user_id}', '#{session_id}', NULL, #{val}, NOW())"
    events_count += 1
  end

  # Insert in batches of 500 for performance
  if event_sql_values.size >= 500
    sql = "INSERT INTO events (id, project_id, name, timestamp, environment, service, host, properties, tags, user_id, session_id, request_id, value, created_at) VALUES #{event_sql_values.join(', ')}"
    ActiveRecord::Base.connection.execute(sql)
    event_sql_values = []
    print "."
  end
end

# Insert remaining
if event_sql_values.any?
  sql = "INSERT INTO events (id, project_id, name, timestamp, environment, service, host, properties, tags, user_id, session_id, request_id, value, created_at) VALUES #{event_sql_values.join(', ')}"
  ActiveRecord::Base.connection.execute(sql)
end
puts " #{events_count} events"

# ============================================================================
# DASHBOARDS
# ============================================================================
puts "\nCreating dashboards..."

# Main Overview Dashboard
overview = FluxDashboard.create!(
  project: project,
  name: "Overview",
  description: "High-level metrics and KPIs",
  is_default: true,
  is_public: false
)

# Number widgets - top row
Widget.create!(
  flux_dashboard: overview,
  title: "Online Users",
  widget_type: "number",
  query: { source: "metrics", metric: "users.online", aggregation: "last" },
  display: { format: "number", color: "#10B981", icon: "users" },
  position: { x: 0, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: overview,
  title: "API Requests/min",
  widget_type: "number",
  query: { source: "metrics", metric: "api.requests", aggregation: "rate", time_range: "1h" },
  display: { format: "number", color: "#3B82F6", suffix: "/min" },
  position: { x: 3, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: overview,
  title: "Error Rate",
  widget_type: "number",
  query: { source: "metrics", metric: "errors.total", aggregation: "rate", time_range: "1h" },
  display: { format: "percent", color: "#EF4444", thresholds: { warning: 1, critical: 5 } },
  position: { x: 6, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: overview,
  title: "P95 Response Time",
  widget_type: "number",
  query: { source: "metrics", metric: "response_time", aggregation: "p95", time_range: "1h" },
  display: { format: "duration", suffix: "ms", color: "#8B5CF6", thresholds: { warning: 200, critical: 500 } },
  position: { x: 9, y: 0, w: 3, h: 2 }
)

# Graph widgets - middle section
Widget.create!(
  flux_dashboard: overview,
  title: "Request Volume",
  widget_type: "graph",
  query: { source: "metrics", metric: "api.requests", aggregation: "sum", time_range: "24h", group_by: [ "1h" ] },
  display: { type: "area", color: "#3B82F6", fill: true },
  position: { x: 0, y: 2, w: 6, h: 3 }
)

Widget.create!(
  flux_dashboard: overview,
  title: "Response Time Distribution",
  widget_type: "graph",
  query: { source: "metrics", metric: "response_time", aggregation: "percentiles", time_range: "24h" },
  display: { type: "line", colors: { p50: "#10B981", p95: "#F59E0B", p99: "#EF4444" } },
  position: { x: 6, y: 2, w: 6, h: 3 }
)

# Bar chart for events breakdown
Widget.create!(
  flux_dashboard: overview,
  title: "Events by Type",
  widget_type: "bar",
  query: { source: "events", aggregation: "count", group_by: [ "name" ], time_range: "24h", limit: 10 },
  display: { orientation: "horizontal", color: "#6366F1" },
  position: { x: 0, y: 5, w: 4, h: 3 }
)

# Pie chart for traffic sources
Widget.create!(
  flux_dashboard: overview,
  title: "Traffic Sources",
  widget_type: "pie",
  query: { source: "events", event: "page.view", aggregation: "count", group_by: [ "properties.referrer" ], time_range: "24h" },
  display: { colors: [ "#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6" ] },
  position: { x: 4, y: 5, w: 4, h: 3 }
)

# Table widget for recent errors
Widget.create!(
  flux_dashboard: overview,
  title: "Recent Errors",
  widget_type: "table",
  query: { source: "events", event: "error.occurred", columns: [ "timestamp", "properties.type", "properties.endpoint" ], limit: 10 },
  display: { compact: true },
  position: { x: 8, y: 5, w: 4, h: 3 }
)

# List widget for top pages
Widget.create!(
  flux_dashboard: overview,
  title: "Top Pages",
  widget_type: "list",
  query: { source: "events", event: "page.view", aggregation: "count", group_by: [ "properties.page" ], limit: 5, time_range: "24h" },
  display: { show_counts: true },
  position: { x: 0, y: 8, w: 4, h: 2 }
)

puts "  Created: #{overview.name} (#{overview.widgets.count} widgets)"

# Performance Dashboard
performance = FluxDashboard.create!(
  project: project,
  name: "Performance",
  description: "Application performance metrics",
  is_default: false
)

Widget.create!(
  flux_dashboard: performance,
  title: "Average Response Time",
  widget_type: "number",
  query: { source: "metrics", metric: "response_time", aggregation: "avg", time_range: "1h" },
  display: { format: "duration", suffix: "ms", color: "#10B981" },
  position: { x: 0, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: performance,
  title: "P99 Latency",
  widget_type: "number",
  query: { source: "metrics", metric: "response_time", aggregation: "p99", time_range: "1h" },
  display: { format: "duration", suffix: "ms", color: "#EF4444", thresholds: { warning: 300, critical: 1000 } },
  position: { x: 3, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: performance,
  title: "Database Query Time",
  widget_type: "number",
  query: { source: "metrics", metric: "db.query_time", aggregation: "p95", time_range: "1h" },
  display: { format: "duration", suffix: "ms", color: "#F59E0B" },
  position: { x: 6, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: performance,
  title: "Cache Hit Rate",
  widget_type: "number",
  query: { source: "metrics", metric: "cache.hit_rate", aggregation: "avg", time_range: "1h" },
  display: { format: "percent", color: "#8B5CF6" },
  position: { x: 9, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: performance,
  title: "Response Time by Endpoint",
  widget_type: "graph",
  query: { source: "metrics", metric: "response_time", aggregation: "p95", group_by: [ "tags.endpoint" ], time_range: "24h" },
  display: { type: "line" },
  position: { x: 0, y: 2, w: 8, h: 4 }
)

Widget.create!(
  flux_dashboard: performance,
  title: "Slowest Endpoints",
  widget_type: "bar",
  query: { source: "metrics", metric: "response_time", aggregation: "p95", group_by: [ "tags.endpoint" ], time_range: "1h" },
  display: { orientation: "horizontal", color: "#EF4444" },
  position: { x: 8, y: 2, w: 4, h: 4 }
)

Widget.create!(
  flux_dashboard: performance,
  title: "Memory & CPU",
  widget_type: "graph",
  query: { source: "metrics", metrics: [ "memory.usage", "cpu.utilization" ], time_range: "24h" },
  display: { type: "line", dual_axis: true },
  position: { x: 0, y: 6, w: 12, h: 3 }
)

puts "  Created: #{performance.name} (#{performance.widgets.count} widgets)"

# Business Dashboard
business = FluxDashboard.create!(
  project: project,
  name: "Business",
  description: "Revenue and user metrics",
  is_default: false
)

Widget.create!(
  flux_dashboard: business,
  title: "Revenue Today",
  widget_type: "number",
  query: { source: "events", event: "order.completed", aggregation: "sum", field: "properties.amount", time_range: "today" },
  display: { format: "currency", prefix: "$", color: "#10B981" },
  position: { x: 0, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: business,
  title: "Orders Today",
  widget_type: "number",
  query: { source: "events", event: "order.completed", aggregation: "count", time_range: "today" },
  display: { format: "number", color: "#3B82F6" },
  position: { x: 3, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: business,
  title: "New Signups",
  widget_type: "number",
  query: { source: "events", event: "user.signup", aggregation: "count", time_range: "today" },
  display: { format: "number", color: "#8B5CF6" },
  position: { x: 6, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: business,
  title: "Active Users",
  widget_type: "number",
  query: { source: "events", event: "user.login", aggregation: "unique", field: "user_id", time_range: "24h" },
  display: { format: "number", color: "#F59E0B" },
  position: { x: 9, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: business,
  title: "Revenue Over Time",
  widget_type: "graph",
  query: { source: "events", event: "order.completed", aggregation: "sum", field: "properties.amount", time_range: "7d", group_by: [ "1d" ] },
  display: { type: "bar", color: "#10B981" },
  position: { x: 0, y: 2, w: 6, h: 3 }
)

Widget.create!(
  flux_dashboard: business,
  title: "Signups by Source",
  widget_type: "pie",
  query: { source: "events", event: "user.signup", aggregation: "count", group_by: [ "properties.source" ], time_range: "7d" },
  display: { donut: true },
  position: { x: 6, y: 2, w: 3, h: 3 }
)

Widget.create!(
  flux_dashboard: business,
  title: "Plans Distribution",
  widget_type: "pie",
  query: { source: "events", event: "user.signup", aggregation: "count", group_by: [ "properties.plan" ], time_range: "7d" },
  display: { donut: true },
  position: { x: 9, y: 2, w: 3, h: 3 }
)

Widget.create!(
  flux_dashboard: business,
  title: "Recent Orders",
  widget_type: "table",
  query: { source: "events", event: "order.completed", columns: [ "timestamp", "user_id", "properties.amount", "properties.payment_method" ], limit: 10 },
  display: {},
  position: { x: 0, y: 5, w: 12, h: 3 }
)

puts "  Created: #{business.name} (#{business.widgets.count} widgets)"

# Infrastructure Dashboard
infrastructure = FluxDashboard.create!(
  project: project,
  name: "Infrastructure",
  description: "System health and resources",
  is_default: false
)

Widget.create!(
  flux_dashboard: infrastructure,
  title: "CPU Usage",
  widget_type: "number",
  query: { source: "metrics", metric: "cpu.utilization", aggregation: "avg", time_range: "5m" },
  display: { format: "percent", thresholds: { warning: 70, critical: 90 } },
  position: { x: 0, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: infrastructure,
  title: "Memory Usage",
  widget_type: "number",
  query: { source: "metrics", metric: "memory.usage", aggregation: "last" },
  display: { format: "bytes", suffix: "MB", thresholds: { warning: 700, critical: 900 } },
  position: { x: 3, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: infrastructure,
  title: "Queue Depth",
  widget_type: "number",
  query: { source: "metrics", metric: "queue.depth", aggregation: "last" },
  display: { format: "number", thresholds: { warning: 100, critical: 500 } },
  position: { x: 6, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: infrastructure,
  title: "Error Count",
  widget_type: "number",
  query: { source: "metrics", metric: "errors.total", aggregation: "sum", time_range: "1h" },
  display: { format: "number", color: "#EF4444" },
  position: { x: 9, y: 0, w: 3, h: 2 }
)

Widget.create!(
  flux_dashboard: infrastructure,
  title: "System Resources",
  widget_type: "graph",
  query: { source: "metrics", metrics: [ "cpu.utilization", "memory.usage" ], time_range: "6h" },
  display: { type: "area", stacked: false },
  position: { x: 0, y: 2, w: 12, h: 3 }
)

Widget.create!(
  flux_dashboard: infrastructure,
  title: "Queue Activity",
  widget_type: "graph",
  query: { source: "metrics", metric: "queue.depth", time_range: "6h" },
  display: { type: "line", color: "#F59E0B" },
  position: { x: 0, y: 5, w: 6, h: 3 }
)

Widget.create!(
  flux_dashboard: infrastructure,
  title: "Error Timeline",
  widget_type: "graph",
  query: { source: "metrics", metric: "errors.total", time_range: "24h" },
  display: { type: "bar", color: "#EF4444" },
  position: { x: 6, y: 5, w: 6, h: 3 }
)

puts "  Created: #{infrastructure.name} (#{infrastructure.widgets.count} widgets)"

# ============================================================================
# ANOMALIES
# ============================================================================
puts "\nCreating sample anomalies..."

anomalies_data = [
  {
    source: "metric",
    source_name: "response_time",
    anomaly_type: "spike",
    severity: "critical",
    expected_value: 85.0,
    actual_value: 450.0,
    deviation_percent: 429.4,
    detected_at: 2.hours.ago,
    context: { endpoint: "/api/orders", duration_minutes: 15 }
  },
  {
    source: "metric",
    source_name: "errors.total",
    anomaly_type: "spike",
    severity: "warning",
    expected_value: 2.0,
    actual_value: 12.0,
    deviation_percent: 500.0,
    detected_at: 4.hours.ago,
    context: { error_types: [ "TimeoutError", "ValidationError" ] },
    acknowledged: true
  },
  {
    source: "event",
    source_name: "user.signup",
    anomaly_type: "drop",
    severity: "warning",
    expected_value: 50.0,
    actual_value: 15.0,
    deviation_percent: -70.0,
    detected_at: 6.hours.ago,
    context: { compared_to: "same_hour_yesterday" }
  },
  {
    source: "metric",
    source_name: "cpu.utilization",
    anomaly_type: "trend",
    severity: "info",
    expected_value: 35.0,
    actual_value: 55.0,
    deviation_percent: 57.1,
    detected_at: 1.day.ago,
    context: { trend_direction: "increasing", duration_hours: 6 },
    acknowledged: true
  },
  {
    source: "metric",
    source_name: "queue.depth",
    anomaly_type: "spike",
    severity: "critical",
    expected_value: 20.0,
    actual_value: 350.0,
    deviation_percent: 1650.0,
    detected_at: 30.minutes.ago,
    context: { job_type: "email_notifications" }
  },
  {
    source: "event",
    source_name: "order.completed",
    anomaly_type: "drop",
    severity: "critical",
    expected_value: 100.0,
    actual_value: 5.0,
    deviation_percent: -95.0,
    detected_at: 1.hour.ago,
    context: { potential_cause: "payment_gateway_issues" }
  }
]

anomalies_data.each do |data|
  Anomaly.create!(project: project, **data)
  print "."
end
puts " #{anomalies_data.count} anomalies"

# ============================================================================
# SUMMARY
# ============================================================================
puts "\n" + "=" * 60
puts "Flux seeding complete!"
puts "=" * 60
puts "\nProject: #{project.name}"
puts "  API Key: #{project.api_key}"
puts "  Ingest Key: #{project.ingest_key}"
puts "\nData created:"
puts "  - #{project.metric_definitions.count} metric definitions"
puts "  - #{project.metric_points.count} metric points"
puts "  - #{project.events.count} events"
puts "  - #{project.flux_dashboards.count} dashboards"
puts "  - #{project.flux_dashboards.sum { |d| d.widgets.count }} widgets"
puts "  - #{project.anomalies.count} anomalies"
puts "\nDashboards:"
project.flux_dashboards.each do |dashboard|
  puts "  - #{dashboard.name} (#{dashboard.widgets.count} widgets)#{dashboard.is_default ? ' [default]' : ''}"
end
puts "\nAccess at: http://flux.localhost/dashboard/projects/#{project.platform_project_id}/dashboards"
