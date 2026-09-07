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

ActiveRecord::Schema[8.1].define(version: 2026_09_08_100001) do
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

  create_table "badger_references", force: :cascade do |t|
    t.integer "badge_id", null: false
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.binary "data", null: false
    t.integer "height", null: false
    t.float "opacity", default: 0.5, null: false
    t.float "scale", default: 1.0, null: false
    t.datetime "updated_at", null: false
    t.integer "width", null: false
    t.float "x", default: 0.0, null: false
    t.float "y", default: 0.0, null: false
    t.index ["badge_id"], name: "index_badger_references_on_badge_id", unique: true
  end

  create_table "badger_slot_rules", force: :cascade do |t|
    t.integer "colorway_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.integer "rank", null: false
    t.json "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["colorway_id", "rank"], name: "index_badger_slot_rules_on_colorway_id_and_rank", unique: true
    t.index ["colorway_id"], name: "index_badger_slot_rules_on_colorway_id"
  end

  create_table "pandatone_colors", force: :cascade do |t|
    t.integer "b", null: false
    t.decimal "c", precision: 5, scale: 1, null: false
    t.datetime "created_at", null: false
    t.integer "g", null: false
    t.decimal "k", precision: 5, scale: 1, null: false
    t.decimal "m", precision: 5, scale: 1, null: false
    t.string "name", null: false
    t.integer "r", null: false
    t.string "source_space", null: false
    t.json "tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.decimal "y", precision: 5, scale: 1, null: false
    t.index ["name"], name: "index_pandatone_colors_on_name"
    t.index ["r", "g", "b"], name: "index_pandatone_colors_on_r_and_g_and_b", unique: true
  end

  create_table "pandatone_palette_colors", force: :cascade do |t|
    t.integer "color_id", null: false
    t.datetime "created_at", null: false
    t.integer "palette_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["color_id"], name: "index_pandatone_palette_colors_on_color_id"
    t.index ["palette_id", "color_id"], name: "index_pandatone_palette_colors_on_palette_id_and_color_id", unique: true
    t.index ["palette_id", "position"], name: "index_pandatone_palette_colors_on_palette_id_and_position"
    t.index ["palette_id"], name: "index_pandatone_palette_colors_on_palette_id"
  end

  create_table "pandatone_palettes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.json "tags", default: [], null: false
    t.datetime "updated_at", null: false
    t.index "LOWER(name)", name: "index_pandatone_palettes_on_lower_name", unique: true
  end

  add_foreign_key "badger_colorways", "badger_badges", column: "badge_id"
  add_foreign_key "badger_palette_snapshots", "badger_colorways", column: "colorway_id"
  add_foreign_key "badger_references", "badger_badges", column: "badge_id"
  add_foreign_key "badger_slot_rules", "badger_colorways", column: "colorway_id"
  add_foreign_key "pandatone_palette_colors", "pandatone_colors", column: "color_id"
  add_foreign_key "pandatone_palette_colors", "pandatone_palettes", column: "palette_id"
end
