# frozen_string_literal: true

module Badger
  module Geometry
    # An exact ellipse, parameterized by t in [0, 1] over the full turn.
    # The parametric angle theta = TAU * t runs from +x toward +y, which in
    # SVG's y-down space is clockwise on screen: t = 0 is the right end of
    # the major axis, t = 0.25 the bottom, t = 0.75 the top.
    #
    # This is the spine for every ring of following type. Its arc length has
    # no closed form, so the spine goes through ArcLengthTable like any other
    # piece; that is the whole point of step 1.
    class Ellipse
      include Piece

      KAPPA = 0.5522847498307936 # cubic control distance for a quarter circle

      attr_reader :center, :rx, :ry, :rotation

      def initialize(rx:, ry:, center: Point.new(0.0, 0.0), rotation: 0.0)
        raise ArgumentError, "ellipse radii must be positive" unless rx.positive? && ry.positive?

        @rx = rx.to_f
        @ry = ry.to_f
        @center = center
        @rotation = rotation.to_f
      end

      def self.circle(radius, center: Point.new(0.0, 0.0))
        new(rx: radius, ry: radius, center: center)
      end

      def point(t)
        theta = TAU * t
        center + Point.new(rx * Math.cos(theta), ry * Math.sin(theta)).rotate(rotation)
      end

      def derivative(t)
        theta = TAU * t
        Point.new(-rx * Math.sin(theta), ry * Math.cos(theta)).rotate(rotation) * TAU
      end

      def circle? = (rx - ry).abs < 1e-12

      # Parameter for a parametric angle (radians). Only equals the visual
      # polar angle on a circle.
      def param_at_angle(theta) = (theta / TAU) % 1.0

      # Parameter for a visual polar angle (radians, measured in the parent's
      # space from +x toward +y) - the angle a designer reads off the badge.
      def param_at_polar(phi)
        local = phi - rotation
        param_at_angle(Math.atan2(rx * Math.sin(local), ry * Math.cos(local)))
      end

      def table_resolution = 128

      # Uniform steps in theta, sized for the largest radius of curvature so
      # the chord error stays under tolerance everywhere.
      def flatten(tolerance)
        big = [rx, ry].max
        small = [rx, ry].min
        curvature_radius = big * big / small
        step = tolerance >= curvature_radius ? Math::PI / 2 : 2 * Math.acos(1 - tolerance / curvature_radius)
        n = [(TAU / step).ceil, 8].max
        points = (0..n).map { |i| point(i.to_f / n) }
        points[-1] = points[0] # sin(TAU) is not exactly zero
        points
      end

      def spine(**options) = Spine.new([self], closed: true, **options)

      # Four-cubic approximation (max radial error about 0.03%), for SVG
      # output where an exact <ellipse> element is not wanted.
      def to_cubics
        4.times.map do |q|
          a0 = q * Math::PI / 2
          a1 = a0 + Math::PI / 2
          unit = ->(a) { Point.new(Math.cos(a), Math.sin(a)) }
          tangent = ->(a) { Point.new(-Math.sin(a), Math.cos(a)) }
          local = [
            unit.(a0),
            unit.(a0) + tangent.(a0) * KAPPA,
            unit.(a1) - tangent.(a1) * KAPPA,
            unit.(a1)
          ]
          Cubic.new(*local.map { |p| center + Point.new(p.x * rx, p.y * ry).rotate(rotation) })
        end
      end

      def to_path = Path.new([Path::Subpath.new(segments: to_cubics, closed: true)])
    end
  end
end
