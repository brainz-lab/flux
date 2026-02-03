# CLAUDE.md

> **Secrets Reference**: See `../.secrets.md` (gitignored) for master keys, server access, and MCP tokens.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Flux by Brainz Lab

Custom metrics and events platform for Rails apps. Fourth product in the Brainz Lab suite.

**Domain**: flux.brainzlab.ai

**Tagline**: "Track anything, see everything"

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          FLUX (Rails 8)                          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Dashboard   │  │     API      │  │  MCP Server  │           │
│  │  (Hotwire)   │  │  (JSON API)  │  │   (Ruby)     │           │
│  │ /dashboard/* │  │  /api/v1/*   │  │   /mcp/*     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                           │                  │                   │
│                           ▼                  ▼                   │
│              ┌─────────────────────────────────────┐            │
│              │   PostgreSQL + TimescaleDB          │            │
│              │   (for time-series data)            │            │
│              └─────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              ▲
            ┌─────────────────┴─────────────────┐
            │                                    │
    ┌───────┴───────┐                  ┌────────┴────────┐
    │  SDK (Gem)    │                  │   Claude/AI     │
    │ brainzlab-sdk │                  │  (Uses MCP)     │
    └───────────────┘                  └─────────────────┘
```

## Tech Stack

- **Backend**: Rails 8 API + Dashboard
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL with TimescaleDB extension (for time-series)
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable (real-time updates)
- **MCP Server**: Ruby (integrated into Rails)

## Common Commands

```bash
# Development
bin/rails server
bin/rails console
bin/rails db:migrate

# Testing
bin/rails test
bin/rails test test/models/event_test.rb  # single file

# Docker (from brainzlab root)
docker-compose --profile flux up
docker-compose exec flux bin/rails db:migrate

# Database
bin/rails db:create db:migrate
bin/rails db:seed

# Tailwind
bin/rails tailwindcss:build
```

## Key Models

- **Project**: Links to Platform via `platform_project_id`, has api_key and ingest_key
- **Event**: Discrete occurrences with name, timestamp, properties, tags, value
- **MetricDefinition**: Metric schema (gauge, counter, distribution, set)
- **MetricPoint**: Individual metric data points (TimescaleDB hypertable)
- **AggregatedMetric**: Pre-computed aggregations for dashboards
- **Dashboard**: Custom dashboards with widgets
- **Widget**: Dashboard components (number, graph, bar, pie, table, heatmap)
- **Anomaly**: AI-detected patterns (spikes, drops, trends)

## Data Flow

1. SDK/client sends event or metric to `POST /api/v1/events` or `POST /api/v1/metrics`
2. Data is stored in TimescaleDB hypertables
3. Background jobs aggregate metrics and detect anomalies
4. Dashboard displays real-time metrics and alerts

## MCP Tools

| Tool | Description |
|------|-------------|
| `flux_track` | Track a custom event |
| `flux_query` | Query events with filters |
| `flux_metric` | Get metric values and time series |
| `flux_dashboard` | Get dashboard data with widget values |
| `flux_anomalies` | List detected anomalies |

## API Endpoints

**Events**:
- `POST /api/v1/events` - Track single event
- `POST /api/v1/events/batch` - Batch events
- `GET /api/v1/events` - List events
- `GET /api/v1/events/count` - Count events
- `GET /api/v1/events/stats` - Event statistics

**Metrics**:
- `POST /api/v1/metrics` - Track metric (gauge, counter, distribution, set)
- `POST /api/v1/metrics/batch` - Batch metrics
- `GET /api/v1/metrics` - List metric definitions
- `GET /api/v1/metrics/:name` - Get metric details
- `GET /api/v1/metrics/:name/query` - Query time series

**Dashboards**:
- `GET /api/v1/dashboards` - List dashboards
- `POST /api/v1/dashboards` - Create dashboard
- `GET /api/v1/dashboards/:id` - Get dashboard with widgets
- Resources for widgets nested under dashboards

**Anomalies**:
- `GET /api/v1/anomalies` - List anomalies
- `POST /api/v1/anomalies/:id/acknowledge` - Acknowledge anomaly

**Batch**:
- `POST /api/v1/flux/batch` - Combined events + metrics

**MCP**:
- `GET /mcp/tools` - List tools
- `POST /mcp/tools/:name` - Call tool
- `POST /mcp/rpc` - JSON-RPC protocol

Authentication: `Authorization: Bearer <key>` or `X-API-Key: <key>`

## Event Payload Format

```json
{
  "name": "user.signup",
  "timestamp": "2024-12-21T10:00:00Z",
  "properties": {
    "plan": "pro",
    "source": "google_ads"
  },
  "tags": {
    "environment": "production"
  },
  "user_id": "user_123",
  "value": 29.99
}
```

## Metric Types

- **Gauge**: Current value (overwrites) - e.g., `users.online`, `queue.depth`
- **Counter**: Incrementing values - e.g., `api.requests`, `emails.sent`
- **Distribution**: Statistical aggregation - e.g., `response_time`, `order_value`
- **Set**: Unique counts (cardinality) - e.g., `daily_active_users`

## SDK Usage

```ruby
# Track events
BrainzLab::Flux.track("user.signup", {
  user_id: user.id,
  plan: "pro",
  value: 29.99
})

# Track metrics
BrainzLab::Flux.gauge("users.online", 234)
BrainzLab::Flux.increment("api.requests")
BrainzLab::Flux.distribution("response_time", 145.2)
BrainzLab::Flux.set("daily_active_users", user.id)

# Time operations
BrainzLab::Flux.measure("pdf.generate", tags: { pages: 10 }) do
  generate_pdf(document)
end
```

## Anomaly Detection

The `AnomalyDetector` service compares recent data with baselines:
- Compares current hour with same hour yesterday
- Detects spikes (>3x baseline) and drops (<30% baseline)
- Severity levels: info (0-50%), warning (50-100%), critical (>100%)

## Background Jobs

| Job | Schedule | Description |
|-----|----------|-------------|
| `AnomalyDetectionJob` | Every 15 min | Detect anomalies in events/metrics |
| `MetricAggregationJob` | Hourly | Pre-compute metric aggregations |
| `CleanupOldDataJob` | Daily | Remove data past retention period |

## Design Principles

- Clean, minimal UI like Anthropic/Claude
- Use Hotwire for real-time updates
- TimescaleDB hypertables for efficient time-series queries
- API-first design (dashboard sits on top of API)
- Pre-aggregate metrics for fast dashboard queries
- Buffered batch sending from SDK for performance

## Kamal Production Access

**IMPORTANT**: When using `kamal app exec --reuse`, docker exec doesn't inherit container environment variables. You must pass `SECRET_KEY_BASE` explicitly.

```bash
# Navigate to this service directory
cd /Users/afmp/brainz/brainzlab/flux

# Get the master key (used as SECRET_KEY_BASE)
cat config/master.key

# Run Rails console commands
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> 'bin/rails runner "<ruby_code>"'

# Example: Count records
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> 'bin/rails runner "puts Event.count"'
```

### Running Complex Scripts

For multi-line Ruby scripts:

```bash
# 1. Create script locally
cat > /tmp/my_script.rb << 'RUBY'
Event.order(created_at: :desc).limit(10).each { |e| puts "#{e.name}: #{e.value}" }
RUBY

# 2. Copy to server
scp /tmp/my_script.rb <user>@<primary-server>:/tmp/my_script.rb

# 3. Get container name and run
ssh <user>@<primary-server> 'CONTAINER=$(docker ps --filter "name=flux-web" --format "{{.Names}}" | head -1) && \
  docker cp /tmp/my_script.rb $CONTAINER:/tmp/my_script.rb && \
  docker exec -e SECRET_KEY_BASE=<master_key> $CONTAINER bin/rails runner /tmp/my_script.rb'
```

### Other Kamal Commands

```bash
kamal deploy              # Deploy
kamal app logs -f         # View logs
kamal lock release        # Release stuck lock
kamal secrets print       # Print evaluated secrets
```
