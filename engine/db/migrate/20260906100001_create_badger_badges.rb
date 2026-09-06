class CreateBadgerBadges < ActiveRecord::Migration[8.0]
  def change
    create_table :badger_badges do |t|
      t.string :name, null: false
      t.json :spec, null: false, default: {}
      t.timestamps
    end

    add_index :badger_badges, "LOWER(name)", unique: true, name: "index_badger_badges_on_lower_name"
  end
end
