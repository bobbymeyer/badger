# A rule is for a rank on the badge's ladder, and `slot` in Pandatone's
# dresser is the position in the palette an assigned rule names. One word
# for one thing.
class RenameBadgerSlotRulesSlotToRank < ActiveRecord::Migration[8.0]
  def change
    rename_column :badger_slot_rules, :slot, :rank
  end
end
