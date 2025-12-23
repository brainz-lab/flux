class CreateWidgets < ActiveRecord::Migration[8.0]
  def change
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
