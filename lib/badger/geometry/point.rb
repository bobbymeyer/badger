# frozen_string_literal: true

module Badger
  module Geometry
    # An immutable 2D point / vector. Coordinates follow SVG conventions:
    # x grows to the right, y grows downward.
    Point = Data.define(:x, :y) do
      def self.[](x, y) = new(x: x.to_f, y: y.to_f)

      def +(other) = Point.new(x + other.x, y + other.y)
      def -(other) = Point.new(x - other.x, y - other.y)
      def *(scalar) = Point.new(x * scalar, y * scalar)
      def /(scalar) = Point.new(x / scalar.to_f, y / scalar.to_f)
      def -@ = Point.new(-x, -y)

      def dot(other) = x * other.x + y * other.y
      def cross(other) = x * other.y - y * other.x
      def length = Math.sqrt(x * x + y * y)
      def distance_to(other) = (self - other).length
      def lerp(other, t) = Point.new(x + (other.x - x) * t, y + (other.y - y) * t)

      def normalized
        len = length
        raise Badger::Error, "cannot normalize a zero-length vector" if len.zero?

        Point.new(x / len, y / len)
      end

      # The vector turned a quarter turn toward the "up" side of a tangent.
      # For a left-to-right tangent (1, 0) in y-down coordinates this is
      # (0, -1): the direction glyph ascenders point when the glyph sits on
      # the tangent reading left to right.
      def perp = Point.new(y, -x)

      def rotate(radians)
        c = Math.cos(radians)
        s = Math.sin(radians)
        Point.new(x * c - y * s, x * s + y * c)
      end

      # Direction in radians, measured from +x toward +y (clockwise on screen).
      def angle = Math.atan2(y, x)

      def to_a = [x, y]
      def approx?(other, epsilon = 1e-9) = (x - other.x).abs <= epsilon && (y - other.y).abs <= epsilon
      def to_s = "(#{Geometry.fmt(x)}, #{Geometry.fmt(y)})"
    end
  end
end
