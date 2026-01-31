# Flux

Custom metrics and events platform for Rails apps.

[![CI](https://github.com/brainz-lab/flux/actions/workflows/ci.yml/badge.svg)](https://github.com/brainz-lab/flux/actions/workflows/ci.yml)
[![CodeQL](https://github.com/brainz-lab/flux/actions/workflows/codeql.yml/badge.svg)](https://github.com/brainz-lab/flux/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/brainz-lab/flux/graph/badge.svg)](https://codecov.io/gh/brainz-lab/flux)
[![License: OSAaSy](https://img.shields.io/badge/License-OSAaSy-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.2+-red.svg)](https://www.ruby-lang.org)

## Quick Start

```bash
# Install SDK
gem 'brainzlab'

# Configure and track
BrainzLab::Flux.track("user.signup", user_id: user.id, plan: "pro")
BrainzLab::Flux.gauge("users.online", 234)
```

## Installation

### With Docker

```bash
docker pull brainzllc/flux:latest

docker run -d \
  -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host:5432/flux \
  -e REDIS_URL=redis://host:6379/4 \
  -e RAILS_MASTER_KEY=your-master-key \
  brainzllc/flux:latest
```

### Install SDK

```ruby
# Gemfile
gem 'brainzlab'
```

```ruby
# config/initializers/brainzlab.rb
BrainzLab.configure do |config|
  config.flux_key = ENV['FLUX_API_KEY']
end
```

### Local Development

```bash
bin/setup
bin/rails server
```

## Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection | Yes |
| `REDIS_URL` | Redis connection | Yes |
| `RAILS_MASTER_KEY` | Rails credentials | Yes |
| `BRAINZLAB_PLATFORM_URL` | Platform URL for auth | Yes |

### Tech Stack

- **Ruby** 3.4.7 / **Rails** 8.1
- **PostgreSQL** 16 with TimescaleDB (time-series)
- **Redis** 7
- **Hotwire** (Turbo + Stimulus) / **Tailwind CSS**
- **Solid Queue** / **Solid Cache** / **Solid Cable**

## Usage

### Track Events

```ruby
# Track custom events
BrainzLab::Flux.track("user.signup", {
  user_id: user.id,
  plan: "pro",
  value: 29.99
})
```

### Track Metrics

```ruby
# Gauges - current value (overwrites)
BrainzLab::Flux.gauge("users.online", 234)
BrainzLab::Flux.gauge("queue.depth", 42)

# Counters - incrementing values
BrainzLab::Flux.increment("api.requests")
BrainzLab::Flux.increment("emails.sent", tags: { type: "welcome" })

# Distributions - statistical aggregation
BrainzLab::Flux.distribution("response_time", 145.2)
BrainzLab::Flux.distribution("order_value", 99.99)

# Sets - unique counts (cardinality)
BrainzLab::Flux.set("daily_active_users", user.id)

# Measure timing
BrainzLab::Flux.measure("pdf.generate", tags: { pages: 10 }) do
  generate_pdf(document)
end
```

### Event Payload Format

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

### Metric Types

| Type | Description | Example |
|------|-------------|---------|
| **Gauge** | Current value (overwrites) | `users.online`, `queue.depth` |
| **Counter** | Incrementing values | `api.requests`, `emails.sent` |
| **Distribution** | Statistical aggregation | `response_time`, `order_value` |
| **Set** | Unique counts (cardinality) | `daily_active_users` |

### Dashboards

Build custom dashboards with widgets:
- **Number** - Single metric value
- **Graph** - Time series chart
- **Bar** - Bar chart comparison
- **Pie** - Distribution breakdown
- **Table** - Data table
- **Heatmap** - Activity visualization

### Anomaly Detection

AI-powered anomaly detection:
- Compares current data with historical baselines
- Detects spikes (>3x baseline) and drops (<30% baseline)
- Severity levels: info, warning, critical

## API Reference

### Events
- `POST /api/v1/events` - Track single event
- `POST /api/v1/events/batch` - Batch events
- `GET /api/v1/events` - List events
- `GET /api/v1/events/count` - Count events
- `GET /api/v1/events/stats` - Event statistics

### Metrics
- `POST /api/v1/metrics` - Track metric
- `POST /api/v1/metrics/batch` - Batch metrics
- `GET /api/v1/metrics` - List metric definitions
- `GET /api/v1/metrics/:name` - Get metric details
- `GET /api/v1/metrics/:name/query` - Query time series

### Dashboards
- `GET /api/v1/dashboards` - List dashboards
- `POST /api/v1/dashboards` - Create dashboard
- `GET /api/v1/dashboards/:id` - Get dashboard with widgets

### MCP Tools

| Tool | Description |
|------|-------------|
| `flux_track` | Track a custom event |
| `flux_query` | Query events with filters |
| `flux_metric` | Get metric values and time series |
| `flux_dashboard` | Get dashboard data with widget values |
| `flux_anomalies` | List detected anomalies |

Full documentation: [docs.brainzlab.ai/products/flux](https://docs.brainzlab.ai/products/flux/overview)

## Self-Hosting

### Docker Compose

```yaml
services:
  flux:
    image: brainzllc/flux:latest
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/flux
      REDIS_URL: redis://redis:6379/4
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      BRAINZLAB_PLATFORM_URL: http://platform:3000
    depends_on:
      - db
      - redis
```

### Testing

```bash
bin/rails test
bin/rubocop
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for development setup and contribution guidelines.

## License

This project is licensed under the [OSAaSy License](LICENSE).
