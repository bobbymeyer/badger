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
        rules: (0...colorway.badge.slot_count).map { |rank| rule(colorway.rule_for(rank)) },
        colors: colorway.colors
      )
    end

    def many(colorways)
      colorways.map { |colorway| summary(colorway) }
    end

    # The rule, not the colour it happened to produce; `colors` beside it is
    # the answer for a consumer that does not need to know why.
    def rule(rule)
      { rank: rule.rank, kind: rule.kind, settings: rule.settings }
    end
  end
end
