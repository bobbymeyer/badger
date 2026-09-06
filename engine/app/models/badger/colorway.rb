# A badge wearing a palette. The badge is composed in value and carries no
# colour; this is where colour is said, as a rule per slot over a snapshot
# of the palette, so it survives the badge being edited underneath it.
module Badger
  class Colorway < ApplicationRecord
    belongs_to :badge, inverse_of: :colorways
    has_one :snapshot, class_name: "PaletteSnapshot", dependent: :destroy, inverse_of: :colorway
    has_many :rules, class_name: "SlotRule", dependent: :destroy, inverse_of: :colorway

    validates :palette_id, presence: true
    validate :palette_serves_the_badge, on: :create

    # Choosing a palette takes a snapshot of it. The two are one act.
    def palette=(palette)
      self.palette_id = palette.id
      build_snapshot(palette_name: palette.name, colors: palette.colors.map(&:to_h), taken_at: Time.current)
    end

    def palette_name = snapshot&.palette_name

    # Whether the badge has outgrown the palette. Derived, never stored.
    def invalidated?
      snapshot.nil? || snapshot.size < badge.slot_count
    end

    # The rule a slot carries, or the default it carries by carrying none.
    def rule_for(slot)
      stored_rules[slot] ||= SlotRule.new(colorway: self, slot: slot, kind: "auto_value_match")
    end

    def bind(slot, kind:, **settings)
      rules.find_or_initialize_by(slot: slot).tap do |rule|
        rule.update!(kind: kind, settings: settings.stringify_keys)
        @stored_rules = nil
      end
    end

    # A hex per slot rank, in rank order. Empty while invalidated.
    def colors
      return [] if invalidated?

      count = badge.slot_count
      (0...count).map { |slot| rule_for(slot).color_for(count)&.hex }
    end

    # What Output#to_svg takes: rank to fill.
    def fills
      colors.each_with_index.to_h { |hex, rank| [ rank, hex ] }
    end

    def svg(padding: 0)
      badge.svg(colors: fills, padding: padding)
    end

    def reload(*)
      @stored_rules = nil
      super
    end

    private
      def stored_rules
        @stored_rules ||= rules.index_by(&:slot)
      end

      def palette_serves_the_badge
        return if badge.nil? || snapshot.nil?
        return if snapshot.size >= badge.slot_count

        errors.add(:palette, "has #{snapshot.size} colours and the badge has #{badge.slot_count} slots")
      end
  end
end
