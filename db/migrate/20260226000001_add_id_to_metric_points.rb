class AddIdToMetricPoints < ActiveRecord::Migration[8.0]
  def up
    execute "ALTER TABLE metric_points ADD COLUMN id uuid DEFAULT gen_random_uuid() NOT NULL;"
  end

  def down
    execute "ALTER TABLE metric_points DROP COLUMN id;"
  end
end
