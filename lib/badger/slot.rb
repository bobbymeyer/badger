# frozen_string_literal: true

module Badger
  # A colour slot is a rank, not a colour. 0 is the ground; the highest rank
  # in use is ink. Badger composes in value and a consumer dresses the ranks
  # from a palette afterwards, so nothing here ever holds a hex.
  #
  # Three names cover the register: :ground, :field (a filled band or an
  # interior set apart from the ground) and :ink. Any integer works too.
  module Slot
    NAMED = { ground: 0, field: 1, ink: 2 }.freeze

    def self.rank(slot)
      case slot
      when Integer
        raise ArgumentError, "a slot rank cannot be negative" if slot.negative?

        slot
      when Symbol
        NAMED.fetch(slot) { raise ArgumentError, "unknown slot #{slot.inspect}; use #{NAMED.keys.join(', ')} or an integer" }
      else
        raise ArgumentError, "a slot is a name or an integer rank"
      end
    end

    def self.name_for(dense_rank, count)
      return "ink" if count == 1
      return "ground" if dense_rank.zero?
      return "ink" if dense_rank == count - 1

      count == 3 ? "field" : "field-#{dense_rank}"
    end
  end

  # The value ladder an undressed badge renders in: paper at 98% lightness
  # down to ink at 18%, the same ladder its-swiss and Stripeclub use, so a
  # badge without a palette sits in the interface rather than on top of it.
  module Value
    PAPER = 0.98
    INK = 0.18

    # Lightness for a dense rank among `count` slots, paper to ink.
    def self.lightness(dense_rank, count)
      return INK if count <= 1

      PAPER - (PAPER - INK) * dense_rank / (count - 1.0)
    end

    # A neutral grey at an OKLab lightness, as a hex.
    def self.grey(lightness)
      linear = lightness**3
      channel = linear <= 0.0031308 ? 12.92 * linear : 1.055 * (linear**(1 / 2.4)) - 0.055
      byte = (channel.clamp(0.0, 1.0) * 255).round
      format("#%02x%02x%02x", byte, byte, byte)
    end
  end
end
