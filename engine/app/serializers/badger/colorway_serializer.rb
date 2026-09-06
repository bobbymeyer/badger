module Badger
  module ColorwaySerializer
    module_function

    def summary(colorway)
      { id: colorway.id, badge_id: colorway.badge_id, palette_id: colorway.palette_id,
        palette_name: colorway.palette_name, invalidated: colorway.invalidated? }
    end

    def one(colorway)
      summary(colorway).merge(
        taken_at: colorway.snapshot&.taken_at&.iso8601,
        rules: (0...colorway.badge.slot_count).map { |slot| rule(colorway.rule_for(slot)) },
        colors: colorway.colors
      )
    end

    def many(colorways)
      colorways.map { |colorway| summary(colorway) }
    end

    def rule(rule)
      { slot: rule.slot, kind: rule.kind, settings: rule.settings }
    end
  end
end
