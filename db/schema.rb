# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2024_12_23_000008) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "timescaledb"

  create_table "aggregated_metrics", id: false, force: :cascade do |t|
    t.float "avg"
    t.text "bucket_size", null: false
    t.timestamptz "bucket_time", null: false
    t.float "count"
    t.float "max"
    t.text "metric_name", null: false
    t.float "min"
    t.float "p50"
    t.float "p95"
    t.float "p99"
    t.uuid "project_id", null: false
    t.float "sum"
    t.jsonb "tags", default: {}
    t.index ["bucket_time"], name: "aggregated_metrics_bucket_time_idx", order: :desc
    t.index ["project_id", "metric_name", "bucket_size", "bucket_time"], name: "idx_aggregated_metrics_lookup"
  end
