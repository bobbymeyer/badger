# frozen_string_literal: true

module Badger
  module Geometry
    class Cubic
      include Piece

      MAX_FLATTEN_DEPTH = 16

      attr_reader :p0, :p1, :p2, :p3

      def initialize(p0, p1, p2, p3)
        @p0 = p0
        @p1 = p1
        @p2 = p2
        @p3 = p3
      end

      # Degree elevation of a quadratic Bézier, exact.
      def self.from_quadratic(p0, control, p2)
        new(p0, p0 + (control - p0) * (2.0 / 3), p2 + (control - p2) * (2.0 / 3), p2)
      end

      def point(t)
        mt = 1.0 - t
        a = mt * mt * mt
        b = 3.0 * mt * mt * t
        c = 3.0 * mt * t * t
        d = t * t * t
        Point.new(a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                  a * p0.y + b * p1.y + c * p2.y + d * p3.y)
      end

      def derivative(t)
        mt = 1.0 - t
        (p1 - p0) * (3.0 * mt * mt) + (p2 - p1) * (6.0 * mt * t) + (p3 - p2) * (3.0 * t * t)
      end

      def split(t = 0.5)
        p01 = p0.lerp(p1, t)
        p12 = p1.lerp(p2, t)
        p23 = p2.lerp(p3, t)
        p012 = p01.lerp(p12, t)
        p123 = p12.lerp(p23, t)
        mid = p012.lerp(p123, t)
        [Cubic.new(p0, p01, p012, mid), Cubic.new(mid, p123, p23, p3)]
      end

      # True when both control points lie within `tolerance` of the chord,
      # which bounds the curve's own deviation from the chord.
      def flat?(tolerance)
        chord = p3 - p0
        len = chord.length
        return p1.distance_to(p0) <= tolerance && p2.distance_to(p0) <= tolerance if len < 1e-12

        d1 = (p1 - p0).cross(chord).abs / len
        d2 = (p2 - p0).cross(chord).abs / len
        [d1, d2].max <= tolerance
      end

      def flatten(tolerance, depth = 0)
        return [p0, p3] if flat?(tolerance) || depth >= MAX_FLATTEN_DEPTH

        a, b = split
        a.flatten(tolerance, depth + 1)[0...-1] + b.flatten(tolerance, depth + 1)
      end

      def reversed = Cubic.new(p3, p2, p1, p0)
      def transform(affine) = Cubic.new(*[p0, p1, p2, p3].map { |p| affine.apply(p) })

      def to_d
        "C #{[p1, p2, p3].map { |p| "#{Geometry.fmt(p.x)} #{Geometry.fmt(p.y)}" }.join(' ')}"
      end

      def ==(other)
        other.is_a?(Cubic) && p0 == other.p0 && p1 == other.p1 && p2 == other.p2 && p3 == other.p3
      end
    end
  end
end
