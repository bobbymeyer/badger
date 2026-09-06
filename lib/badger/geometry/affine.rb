# frozen_string_literal: true

module Badger
  module Geometry
    # 2D affine transform in SVG matrix order: x' = a*x + c*y + e, y' = b*x + d*y + f.
    Affine = Data.define(:a, :b, :c, :d, :e, :f) do
      def self.identity = new(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
      def self.translate(x, y) = new(1.0, 0.0, 0.0, 1.0, x.to_f, y.to_f)
      def self.scale(sx, sy = sx) = new(sx.to_f, 0.0, 0.0, sy.to_f, 0.0, 0.0)

      def self.rotate(radians)
        cos = Math.cos(radians)
        sin = Math.sin(radians)
        new(cos, sin, -sin, cos, 0.0, 0.0)
      end

      def apply(point)
        Point.new(a * point.x + c * point.y + e, b * point.x + d * point.y + f)
      end

      # self * other applies `other` first, then self.
      def *(other)
        Affine.new(a * other.a + c * other.b,
                   b * other.a + d * other.b,
                   a * other.c + c * other.d,
                   b * other.c + d * other.d,
                   a * other.e + c * other.f + e,
                   b * other.e + d * other.f + f)
      end

      def to_svg
        "matrix(#{[a, b, c, d, e, f].map { |v| Geometry.fmt(v) }.join(' ')})"
      end
    end
  end
end
