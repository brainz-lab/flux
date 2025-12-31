class CreateAnomalies < ActiveRecord::Migration[8.0]
  def change
    create_table :anomalies, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :source, null: false       # metric, event
      t.string :source_name, null: false  # metric/event name

      t.string :anomaly_type, null: false # spike, drop, trend, seasonality
      t.string :severity, default: 'info' # info, warning, critical

      t.float :expected_value
      t.float :actual_value
      t.float :deviation_percent

      t.datetime :detected_at, null: false
      t.datetime :started_at
      t.datetime :ended_at

      t.jsonb :context, default: {}
      t.boolean :acknowledged, default: false

      t.timestamps

      t.index [ :project_id, :detected_at ]
      t.index [ :project_id, :source_name ]
      t.index [ :project_id, :severity ]
      t.index [ :project_id, :acknowledged ]
    end
  end
end
