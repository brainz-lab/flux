class CreateMetricDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :metric_definitions, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false
      t.string :display_name
      t.text :description

      t.string :metric_type, null: false  # gauge, counter, distribution, set
      t.string :unit                       # ms, bytes, requests, usd, etc.

      t.jsonb :tags_schema, default: {}    # Expected tags
      t.jsonb :aggregations, default: []   # Pre-compute these: avg, p95, sum

      t.timestamps

      t.index [:project_id, :name], unique: true
    end
  end
end
