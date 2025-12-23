class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    # Create events table without primary key (TimescaleDB hypertable)
    execute <<-SQL
      CREATE TABLE events (
        id uuid DEFAULT gen_random_uuid() NOT NULL,
        project_id uuid NOT NULL,
        name text NOT NULL,
        timestamp timestamptz NOT NULL,
        environment text,
        service text,
        host text,
        properties jsonb DEFAULT '{}',
        tags jsonb DEFAULT '{}',
        user_id text,
        session_id text,
        request_id text,
        value numeric,
        created_at timestamptz NOT NULL DEFAULT NOW()
      );
    SQL

    # Convert to hypertable for TimescaleDB
    execute "SELECT create_hypertable('events', 'timestamp', if_not_exists => true);"

    # Indexes for common queries (must include timestamp for hypertables)
    add_index :events, [:project_id, :name, :timestamp]
    add_index :events, [:project_id, :timestamp]
    add_index :events, [:user_id, :timestamp]
    add_index :events, [:session_id, :timestamp]

    # GIN index for JSONB properties
    execute "CREATE INDEX idx_events_properties ON events USING GIN (properties jsonb_path_ops);"
    execute "CREATE INDEX idx_events_tags ON events USING GIN (tags jsonb_path_ops);"
  end
end
