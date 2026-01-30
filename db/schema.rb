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

ActiveRecord::Schema[8.1].define(version: 2026_01_30_194536) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "athletes", force: :cascade do |t|
    t.string "country", limit: 3, null: false
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.string "gender", limit: 1, null: false
    t.string "last_name", null: false
    t.string "license_number"
    t.datetime "updated_at", null: false
    t.index ["country"], name: "index_athletes_on_country"
    t.index ["first_name", "last_name", "gender", "country"], name: "index_athletes_on_name_gender_country"
    t.index ["license_number"], name: "index_athletes_on_license_number", unique: true, where: "(license_number IS NOT NULL)"
  end

  create_table "competitions", force: :cascade do |t|
    t.string "city", null: false
    t.string "country", limit: 3, null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.date "end_date", null: false
    t.string "name", null: false
    t.string "place", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.string "webpage_url", null: false
    t.index ["country"], name: "index_competitions_on_country"
    t.index ["start_date", "end_date"], name: "index_competitions_on_start_date_and_end_date"
    t.index ["start_date"], name: "index_competitions_on_start_date"
  end

  create_table "magic_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "token"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_magic_links_on_token", unique: true
    t.index ["user_id"], name: "index_magic_links_on_user_id"
  end

  create_table "penalties", force: :cascade do |t|
    t.string "category", limit: 1, null: false
    t.text "category_description"
    t.string "category_title", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "penalty_number", null: false
    t.string "sprint_relay"
    t.string "team_individual"
    t.datetime "updated_at", null: false
    t.string "vertical"
    t.index ["category"], name: "index_penalties_on_category"
    t.index ["penalty_number"], name: "index_penalties_on_penalty_number", unique: true
  end

  create_table "race_locations", force: :cascade do |t|
    t.string "color_code"
    t.string "course_segment", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "display_order", null: false
    t.boolean "is_standard", default: false, null: false
    t.string "name", null: false
    t.bigint "race_id", null: false
    t.string "segment_position", null: false
    t.datetime "updated_at", null: false
    t.index ["race_id", "display_order"], name: "index_race_locations_on_race_and_order"
    t.index ["race_id", "name"], name: "index_race_locations_on_race_and_name"
    t.index ["race_id"], name: "index_race_locations_on_race_id"
  end

  create_table "race_participations", force: :cascade do |t|
    t.boolean "active_in_heat", default: true
    t.bigint "athlete_id", null: false
    t.integer "bib_number", null: false
    t.datetime "created_at", null: false
    t.datetime "finish_time"
    t.string "heat"
    t.bigint "race_id", null: false
    t.integer "rank"
    t.datetime "start_time"
    t.string "status", default: "registered"
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.index ["athlete_id"], name: "index_race_participations_on_athlete_id"
    t.index ["heat"], name: "index_race_participations_on_heat"
    t.index ["race_id", "athlete_id"], name: "index_race_participations_on_race_id_and_athlete_id", unique: true
    t.index ["race_id", "bib_number"], name: "index_race_participations_on_race_id_and_bib_number", unique: true
    t.index ["race_id"], name: "index_race_participations_on_race_id"
    t.index ["status"], name: "index_race_participations_on_status"
    t.index ["team_id"], name: "index_race_participations_on_team_id"
  end

  create_table "race_type_location_templates", force: :cascade do |t|
    t.string "color_code"
    t.string "course_segment", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "display_order", null: false
    t.boolean "is_standard", default: false, null: false
    t.string "name", null: false
    t.bigint "race_type_id", null: false
    t.string "segment_position", null: false
    t.datetime "updated_at", null: false
    t.index ["race_type_id", "display_order"], name: "index_race_type_location_templates_on_type_and_order"
    t.index ["race_type_id", "name"], name: "index_race_type_location_templates_on_type_and_name"
    t.index ["race_type_id"], name: "index_race_type_location_templates_on_race_type_id"
  end

  create_table "race_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_race_types_on_name", unique: true
  end

  create_table "races", force: :cascade do |t|
    t.bigint "competition_id", null: false
    t.datetime "created_at", null: false
    t.string "gender_category", default: "M", null: false
    t.integer "heat_number"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "race_type_id", null: false
    t.datetime "scheduled_at"
    t.string "stage_name", null: false
    t.string "stage_type", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["competition_id", "position"], name: "index_races_on_competition_id_and_position", unique: true
    t.index ["competition_id"], name: "index_races_on_competition_id"
    t.index ["gender_category"], name: "index_races_on_gender_category"
    t.index ["race_type_id"], name: "index_races_on_race_type_id"
    t.index ["scheduled_at"], name: "index_races_on_scheduled_at"
    t.index ["status"], name: "index_races_on_status"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.bigint "athlete_1_id", null: false
    t.bigint "athlete_2_id"
    t.integer "bib_number", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "race_id", null: false
    t.string "team_type", null: false
    t.datetime "updated_at", null: false
    t.index ["athlete_1_id"], name: "index_teams_on_athlete_1_id"
    t.index ["athlete_2_id"], name: "index_teams_on_athlete_2_id"
    t.index ["race_id", "bib_number"], name: "index_teams_on_race_id_and_bib_number", unique: true
    t.index ["race_id"], name: "index_teams_on_race_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.bigint "role_id"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "magic_links", "users"
  add_foreign_key "race_locations", "races"
  add_foreign_key "race_participations", "athletes"
  add_foreign_key "race_participations", "races"
  add_foreign_key "race_participations", "teams"
  add_foreign_key "race_type_location_templates", "race_types"
  add_foreign_key "races", "competitions"
  add_foreign_key "races", "race_types"
  add_foreign_key "sessions", "users"
  add_foreign_key "teams", "athletes", column: "athlete_1_id"
  add_foreign_key "teams", "athletes", column: "athlete_2_id"
  add_foreign_key "teams", "races"
  add_foreign_key "users", "roles"
end
