# frozen_string_literal: true

module Badger
  # Locators: a point in a parent container's space. Four kinds, from the
  # handoff: centroid, polar (angle, radius), axial (fractions of the
  # parent's bounds) and on-path (arc length along the parent's path).
  # Resolving one yields an Anchor: the point, plus a direction where the
  # locator has one (the tangent on a path, the radial on a polar).
  module Locator
    Anchor = Data.define(:point, :angle) do
      def degrees = angle && angle * 180.0 / Math::PI
    end

    def self.centroid = Centroid.new
    def self.polar(angle:, radius:) = Polar.new(angle: angle, radius: radius)
    def self.axial(x, y) = Axial.new(x: x, y: y)
    def self.on_path(fraction: nil, length: nil) = OnPath.new(fraction: fraction, length: length)

    class Centroid
      def resolve(container) = Anchor.new(point: container.centroid, angle: nil)
      def to_s = "centroid"
    end

    # angle in degrees, visual: 0 is right, 90 is down (y-down space), -90 up.
    class Polar
      attr_reader :angle, :radius

      def initialize(angle:, radius:)
        @angle = angle.to_f
        @radius = radius.to_f
      end

      def radians = angle * Math::PI / 180.0

      def resolve(container)
        point = container.centroid + Geometry::Point.new(Math.cos(radians), Math.sin(radians)) * radius
        Anchor.new(point: point, angle: radians)
      end

      def to_s = "polar(#{angle}deg, #{radius})"
    end

    # x, y as fractions of the parent's bounds: (0, 0) top-left, (1, 1) bottom-right.
    class Axial
      attr_reader :x, :y

      def initialize(x:, y:)
        @x = x.to_f
        @y = y.to_f
      end

      def resolve(container)
        min, max = container.bounds
        Anchor.new(point: Geometry::Point.new(min.x + (max.x - min.x) * x, min.y + (max.y - min.y) * y), angle: nil)
      end

      def to_s = "axial(#{x}, #{y})"
    end

    # A point on the parent's path by arc length, absolute or as a fraction
    # of the whole; the anchor's angle is the path tangent there.
    class OnPath
      attr_reader :fraction, :length

      def initialize(fraction: nil, length: nil)
        raise ArgumentError, "give fraction: or length:, not both" if fraction && length
        raise ArgumentError, "on_path needs fraction: or length:" unless fraction || length

        @fraction = fraction&.to_f
        @length = length&.to_f
      end

      def resolve(container)
        s = length || container.length * fraction
        at = container.spine.at(s)
        Anchor.new(point: at.point, angle: at.angle)
      end

      def to_s = length ? "on_path(#{length})" : "on_path(#{fraction * 100}%)"
    end
  end
end
