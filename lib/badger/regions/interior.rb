# frozen_string_literal: true

module Badger
  module Regions
    # What remains inside the innermost offset. Answers the geometry fit
    # modes need: bounds, centroid, and the horizontal or vertical chord at
    # a given position.
    class Interior < Base
      attr_reader :inside

      def initialize(container, inside:, visible:, name:, slot: :ink)
        raise ArgumentError, "inside: must be zero or negative (an inward offset)" if inside.positive?

        super(container, visible: visible, name: name, slot: slot)
        @inside = inside.to_f
      end

      def spine = container.offset(inside)
      def path = spine.to_path(tolerance: tolerance)
      def polygon = (@polygon ||= spine.flatten(tolerance))

      # Area centroid of the region.
      def centroid
        @centroid ||= begin
          pts = polygon
          twice_area = 0.0
          cx = 0.0
          cy = 0.0
          pts.each_index do |i|
            a = pts[i]
            b = pts[(i + 1) % pts.size]
            cross = a.x * b.y - b.x * a.y
            twice_area += cross
            cx += (a.x + b.x) * cross
            cy += (a.y + b.y) * cross
          end
          twice_area.abs < 1e-12 ? bounds.reduce(:+) / 2 : Geometry::Point.new(cx / (3 * twice_area), cy / (3 * twice_area))
        end
      end

      # Every horizontal span [x0, x1] the region covers at height y, sorted.
      def spans_at_y(y) = spans(polygon.map { |p| [p.x, p.y] }, y)

      # Every vertical span [y0, y1] the region covers at x, sorted.
      def spans_at_x(x) = spans(polygon.map { |p| [p.y, p.x] }, x)

      # The horizontal chord at height y: the span containing `through`
      # (default: the centroid's x), else the widest. Nil outside the region.
      def chord_at_y(y, through: nil)
        pick(spans_at_y(y), through || centroid.x)
      end

      # The vertical chord at x, chosen the same way.
      def chord_at_x(x, through: nil)
        pick(spans_at_x(x), through || centroid.y)
      end

      def width_at_y(y, through: nil) = chord_at_y(y, through: through)&.then { |a, b| b - a }
      def height_at_x(x, through: nil) = chord_at_x(x, through: through)&.then { |a, b| b - a }

      private

      # Crossings of the polygon (as [along, across] pairs) with the line
      # across = level, paired into spans by the evenodd rule.
      def spans(points, level)
        crossings = []
        points.each_index do |i|
          (a0, a1) = points[i]
          (b0, b1) = points[(i + 1) % points.size]
          next if a1 == b1
          next unless (a1 <= level && level < b1) || (b1 <= level && level < a1)

          crossings << a0 + (b0 - a0) * (level - a1) / (b1 - a1)
        end
        crossings.sort.each_slice(2).select { |pair| pair.size == 2 }
      end

      def pick(spans, through)
        return nil if spans.empty?

        spans.find { |a, b| a <= through && through <= b } || spans.max_by { |a, b| b - a }
      end
    end
  end
end
