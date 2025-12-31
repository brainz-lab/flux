class CreateDashboards < ActiveRecord::Migration[8.0]
  def change
    create_table :dashboards, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :is_default, default: false
      t.boolean :is_public, default: false  # Public status page

      t.jsonb :layout, default: {}    # Grid layout config
      t.jsonb :settings, default: {}  # Dashboard settings

      t.timestamps

      t.index [ :project_id, :slug ], unique: true
      t.index [ :project_id, :is_default ]
    end
  end
end
