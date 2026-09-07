# What one of a badge's colour slots resolves to. A rule, not an assignment:
# a colorway that stored hexes would be wrong the moment the badge under it
# changed, and a rule is still right.
#
# The two kinds are Pandatone's dresser's: by rank on the badge's ladder
# against the palette's lightness ranks, or a position in the palette's own
# order. What is this engine's is which rank the rule is for.
module Badger
  class SlotRule < ApplicationRecord
    include Pandatone::Dresser::Rule

    validates :rank, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    def color
      binds_to_rank? ? color_at_rank(rank, of: colorway.slot_count) : assigned_color
    end

    # A badge with one slot is its ink, not its ground: the type on a plain
    # badge is the one thing that takes a colour, and it takes the darkest.
    def color_at_rank(rank, of:)
      return colorway.snapshot.palette.ranked.last if of <= 1

      super
    end
  end
end
