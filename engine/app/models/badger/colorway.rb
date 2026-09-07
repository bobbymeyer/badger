# A badge wearing a palette. The badge is composed in value and carries no
# colour; this is where colour is said, as a rule per slot over a snapshot
# of the palette, so it survives the badge being edited underneath it.
#
# The palette, the snapshot, invalidation and drift are Pandatone's dresser's.
# What is this engine's is the rule per rank and what the badge's fills take.
module Badger
  class Colorway < ApplicationRecord
    include Pandatone::Dresser::Colorway

    belongs_to :badge, inverse_of: :colorways
    has_many :rules, class_name: "SlotRule", dependent: :destroy, inverse_of: :colorway

    delegate :slot_count, to: :badge

    # The rule a rank carries, or the default it carries by carrying none.
    def rule_for(rank)
      stored_rules[rank] ||= SlotRule.new(colorway: self, rank: rank, kind: "auto_value_match")
    end

    def bind(rank, kind:, **settings)
      rules.find_or_initialize_by(rank: rank).tap do |rule|
        rule.update!(kind: kind, settings: settings.stringify_keys)
        @stored_rules = nil
      end
    end

    # A hex per rank, in rank order. Empty while invalidated.
    def colors
      return [] if invalidated?

      (0...slot_count).map { |rank| rule_for(rank).color&.hex }
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
        @stored_rules ||= rules.index_by(&:rank)
      end
  end
end
