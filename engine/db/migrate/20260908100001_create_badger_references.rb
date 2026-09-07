# A reference: the photograph a badge is redrawn from, kept with the badge
# and drawn under it at a chosen strength. One per badge; the image itself
# lives in the row, since a host is not asked to carry an attachment store
# for a picture that is a few hundred kilobytes and never leaves the badge.
class CreateBadgerReferences < ActiveRecord::Migration[8.0]
  def change
    create_table :badger_references do |t|
      t.references :badge, null: false, foreign_key: { to_table: :badger_badges }, index: { unique: true }
      t.string :content_type, null: false
      t.binary :data, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      # Where the image's centre sits in the badge's units, how many units an
      # image pixel is, and how strongly it shows.
      t.float :x, null: false, default: 0.0
      t.float :y, null: false, default: 0.0
      t.float :scale, null: false, default: 1.0
      t.float :opacity, null: false, default: 0.5
      t.timestamps
    end
  end
end
