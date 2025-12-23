class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    create_table :projects, id: :uuid do |t|
      t.string :platform_project_id, null: false
      t.string :name
      t.string :slug
      t.text :description

      t.string :environment, default: "development"
      t.string :api_key
      t.string :ingest_key

      # Counters
      t.bigint :events_count, default: 0
      t.bigint :metrics_count, default: 0

      # Settings
      t.integer :retention_days, default: 90
      t.jsonb :settings, default: {}

      t.timestamps

      t.index :platform_project_id, unique: true
      t.index :slug, unique: true
      t.index :api_key, unique: true
      t.index :ingest_key, unique: true
    end
  end
end
