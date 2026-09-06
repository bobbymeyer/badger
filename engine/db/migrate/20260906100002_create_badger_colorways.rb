class CreateBadgerColorways < ActiveRecord::Migration[8.0]
  def change
    create_table :badger_colorways do |t|
      t.references :badge, null: false, foreign_key: { to_table: :badger_badges }
      t.integer :palette_id, null: false
      t.timestamps
    end

    create_table :badger_palette_snapshots do |t|
      t.references :colorway, null: false, foreign_key: { to_table: :badger_colorways }, index: { unique: true }
      t.string :palette_name
      t.json :colors, null: false, default: []
      t.datetime :taken_at, null: false
      t.timestamps
    end

    create_table :badger_slot_rules do |t|
      t.references :colorway, null: false, foreign_key: { to_table: :badger_colorways }
      t.integer :slot, null: false
      t.string :kind, null: false
      t.json :settings, null: false, default: {}
      t.timestamps
    end

    add_index :badger_slot_rules, [ :colorway_id, :slot ], unique: true
  end
end
