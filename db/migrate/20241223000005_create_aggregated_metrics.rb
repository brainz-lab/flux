class CreateAggregatedMetrics < ActiveRecord::Migration[8.0]
  def change
    # Pre-aggregated metrics (1m, 5m, 1h, 1d buckets)
    execute <<-SQL
      CREATE TABLE aggregated_metrics (
        project_id uuid NOT NULL,
        metric_name text NOT NULL,
        bucket_size text NOT NULL,
        bucket_time timestamptz NOT NULL,
        sum double precision,
        count double precision,
        avg double precision,
        min double precision,
        max double precision,
        p50 double precision,
        p95 double precision,
        p99 double precision,
        tags jsonb DEFAULT '{}'
      );
    SQL

    # Convert to hypertable
    execute "SELECT create_hypertable('aggregated_metrics', 'bucket_time', if_not_exists => true);"

    # Composite index for queries
    add_index :aggregated_metrics, [:project_id, :metric_name, :bucket_size, :bucket_time],
              name: 'idx_aggregated_metrics_lookup'
  end
end
