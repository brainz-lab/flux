class CreateMetricPoints < ActiveRecord::Migration[8.0]
  def change
    # Create table without primary key for TimescaleDB
    execute <<-SQL
      CREATE TABLE metric_points (
        project_id uuid NOT NULL,
        metric_name text NOT NULL,
        timestamp timestamptz NOT NULL,
        value double precision,
        sum double precision,
        count double precision,
        min double precision,
        max double precision,
        p50 double precision,
        p95 double precision,
        p99 double precision,
        cardinality integer,
        hll_data bytea,
        tags jsonb DEFAULT '{}'
      );
    SQL

    # Convert to hypertable
    execute "SELECT create_hypertable('metric_points', 'timestamp', if_not_exists => true);"

    # Indexes
    add_index :metric_points, [:project_id, :metric_name, :timestamp]

    # GIN index for tags
    execute "CREATE INDEX idx_metric_points_tags ON metric_points USING GIN (tags jsonb_path_ops);"

    # Retention policy (keep 90 days by default)
    # Compression and retention policies can be added manually in production
    # execute "SELECT add_retention_policy('metric_points', INTERVAL '90 days', if_not_exists => true);"
  end
end
