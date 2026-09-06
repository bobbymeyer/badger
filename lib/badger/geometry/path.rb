# frozen_string_literal: true

module Badger
  module Geometry
    # An SVG-style path: one or more subpaths of line and cubic segments.
    # Imported container shapes arrive as one of these; spines are derived
    # from its subpaths.
    class Path
      Subpath = Data.define(:segments, :closed) do
        def spine(**options) = Spine.new(segments, closed: closed, **options)
        def start_point = segments.first.start_point
        def closed? = closed

        # A closed subpath's final straight segment back to the start is
        # implied by Z, so it is not written out.
        def closing_line?(segment, start) = segment.is_a?(Line) && segment.p1.approx?(start)

        def to_d
          start = start_point
          parts = ["M #{Geometry.fmt(start.x)} #{Geometry.fmt(start.y)}"]
          drawn = segments
          drawn = drawn[0...-1] if closed && closing_line?(drawn.last, start)
          parts.concat(drawn.map(&:to_d))
          parts << "Z" if closed
          parts.join(" ")
        end
      end

      attr_reader :subpaths

      def initialize(subpaths)
        @subpaths = subpaths.freeze
      end

      def self.parse(d) = SvgPathParser.new(d).path

      def self.polyline(points, closed: false)
        raise ArgumentError, "a polyline needs at least two points" if points.size < 2

        segments = points.each_cons(2).map { |a, b| Line.new(a, b) }
        segments << Line.new(points.last, points.first) if closed && !points.last.approx?(points.first)
        new([Subpath.new(segments: segments, closed: closed)])
      end

      def self.rect(x, y, width, height)
        polyline([Point.new(x, y), Point.new(x + width, y), Point.new(x + width, y + height), Point.new(x, y + height)],
                 closed: true)
      end

      def self.ellipse(center, rx, ry, rotation: 0.0)
        Ellipse.new(rx: rx, ry: ry, center: center, rotation: rotation).to_path
      end

      def self.circle(center, radius) = ellipse(center, radius, radius)

      def spines(**options) = subpaths.map { |s| s.spine(**options) }
      def spine(**options) = spines(**options).first
      def empty? = subpaths.empty?
      def to_d = subpaths.map(&:to_d).join(" ")
      def +(other) = Path.new(subpaths + other.subpaths)

      # [min, max] corners of the flattened geometry.
      def bounds(tolerance: 0.1)
        points = spines.flat_map { |s| s.flatten(tolerance) }
        xs = points.map(&:x)
        ys = points.map(&:y)
        [Point.new(xs.min, ys.min), Point.new(xs.max, ys.max)]
      end
    end
  end
end
