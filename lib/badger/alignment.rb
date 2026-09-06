# frozen_string_literal: true

module Badger
  # Which of a child's nine reference points lands on the locator. Given by
  # name or as an [fx, fy] pair of fractions across the child's bounds.
  module Alignment
    NAMED = {
      top_left: [0.0, 0.0], top: [0.5, 0.0], top_right: [1.0, 0.0],
      left: [0.0, 0.5], center: [0.5, 0.5], right: [1.0, 0.5],
      bottom_left: [0.0, 1.0], bottom: [0.5, 1.0], bottom_right: [1.0, 1.0]
    }.freeze

    def self.fractions(align)
      case align
      when Symbol
        NAMED.fetch(align) { raise ArgumentError, "unknown alignment #{align.inspect}; use one of #{NAMED.keys.join(', ')}" }
      when Array
        raise ArgumentError, "an alignment pair needs two numbers" unless align.size == 2 && align.all?(Numeric)

        align.map(&:to_f)
      else
        raise ArgumentError, "alignment must be a name or an [fx, fy] pair"
      end
    end

    # The reference point on `bounds` ([min, max]) for an alignment.
    def self.reference(bounds, align)
      fx, fy = fractions(align)
      min, max = bounds
      Geometry::Point.new(min.x + (max.x - min.x) * fx, min.y + (max.y - min.y) * fy)
    end
  end
end
