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

ActiveRecord::Schema[8.1].define(version: 2026_09_06_100002) do
  create_table "badger_badges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.json "spec", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(name)", name: "index_badger_badges_on_lower_name", unique: true
  end

  create_table "badger_colorways", force: :cascade do |t|
    t.integer "badge_id", null: false
    t.datetime "created_at", null: false
    t.integer "palette_id", null: false
    t.datetime "updated_at", null: false
    t.index ["badge_id"], name: "index_badger_colorways_on_badge_id"
  end

  create_table "badger_palette_snapshots", force: :cascade do |t|
    t.json "colors", default: [], null: false
    t.integer "colorway_id", null: false
    t.datetime "created_at", null: false
    t.string "palette_name"
    t.datetime "taken_at", null: false
    t.datetime "updated_at", null: false
    t.index ["colorway_id"], name: "index_badger_palette_snapshots_on_colorway_id", unique: true
  end

  create_table "badger_slot_rules", force: :cascade do |t|
    t.integer "colorway_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.json "settings", default: {}, null: false
    t.integer "slot", null: false
    t.datetime "updated_at", null: false
    t.index ["colorway_id", "slot"], name: "index_badger_slot_rules_on_colorway_id_and_slot", unique: true
    t.index ["colorway_id"], name: "index_badger_slot_rules_on_colorway_id"
  end

  add_foreign_key "badger_colorways", "badger_badges", column: "badge_id"
  add_foreign_key "badger_palette_snapshots", "badger_colorways", column: "colorway_id"
  add_foreign_key "badger_slot_rules", "badger_colorways", column: "colorway_id"
end
