# What the palette held at the moment it was chosen.
module Badger
  class PaletteSnapshot < ApplicationRecord
    belongs_to :colorway, inverse_of: :snapshot

    validates :taken_at, presence: true

    def size = colors.size

    def palette
      Pandatone::Palette.from_json("id" => colorway&.palette_id, "name" => palette_name, "colors" => colors)
    end

    # Whether Pandatone's palette has moved since: a colour edited, added,
    # removed or moved is all drift, because an assigned slot names a
    # position. It reports; applying drift is a decision.
    def drifted_from?(palette)
      fingerprint(self.palette.colors) != fingerprint(palette.colors)
    end

    private
      def fingerprint(colors)
        colors.map { |color| [ color.id, color.hex ] }
      end
  end
end
