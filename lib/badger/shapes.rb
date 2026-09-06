# frozen_string_literal: true

module Badger
  # The small set of shape primitives, each a closed path centred on the
  # origin (or on `center:`), wound clockwise on screen so they agree with
  # the ellipse's own parameterization. Anything more parametric belongs to
  # the shape node, which emits container paths for Badger to consume.
  module Shapes
    module_function

    def circle(radius, center: Geometry::Point.new(0.0, 0.0))
      Geometry::Ellipse.circle(radius, center: center)
    end

    def ellipse(rx, ry, center: Geometry::Point.new(0.0, 0.0), rotation: 0.0)
      Geometry::Ellipse.new(rx: rx, ry: ry, center: center, rotation: rotation)
    end

    def rectangle(width, height, center: Geometry::Point.new(0.0, 0.0))
      polygon(center, [[-width / 2.0, -height / 2.0], [width / 2.0, -height / 2.0],
                       [width / 2.0, height / 2.0], [-width / 2.0, height / 2.0]])
    end

    # A diamond: the points sit on the axes.
    def lozenge(width, height, center: Geometry::Point.new(0.0, 0.0))
      polygon(center, [[0.0, -height / 2.0], [width / 2.0, 0.0], [0.0, height / 2.0], [-width / 2.0, 0.0]])
    end

    # Corners are quarter circles; the radius is capped at half the shorter side.
    def rounded_rectangle(width, height, radius:, center: Geometry::Point.new(0.0, 0.0))
      raise ArgumentError, "radius must be positive; use rectangle for a sharp corner" unless radius.positive?

      r = [radius.to_f, width / 2.0, height / 2.0].min
      k = Geometry::Ellipse::KAPPA * r
      w = width / 2.0
      h = height / 2.0
      p = ->(x, y) { center + Geometry::Point.new(x, y) }
      segments = [
        Geometry::Line.new(p.(-w + r, -h), p.(w - r, -h)),
        Geometry::Cubic.new(p.(w - r, -h), p.(w - r + k, -h), p.(w, -h + r - k), p.(w, -h + r)),
        Geometry::Line.new(p.(w, -h + r), p.(w, h - r)),
        Geometry::Cubic.new(p.(w, h - r), p.(w, h - r + k), p.(w - r + k, h), p.(w - r, h)),
        Geometry::Line.new(p.(w - r, h), p.(-w + r, h)),
        Geometry::Cubic.new(p.(-w + r, h), p.(-w + r - k, h), p.(-w, h - r + k), p.(-w, h - r)),
        Geometry::Line.new(p.(-w, h - r), p.(-w, -h + r)),
        Geometry::Cubic.new(p.(-w, -h + r), p.(-w, -h + r - k), p.(-w + r - k, -h), p.(-w + r, -h))
      ].reject { |s| s.is_a?(Geometry::Line) && s.length < 1e-9 }
      Geometry::Path.new([Geometry::Path::Subpath.new(segments: segments, closed: true)])
    end

    # A heater shield: straight top, straight sides down to the shoulder,
    # then two curves meeting at the point. `shoulder` is the fraction of
    # the height the sides stay straight; `curve` is how full the lower
    # curves are, 0 for a chevron straight to the point, 1 for the fullest
    # bulge.
    def shield(width, height, shoulder: 0.4, curve: 0.55, center: Geometry::Point.new(0.0, 0.0))
      raise ArgumentError, "shoulder must be within 0..1" unless (0.0..1.0).cover?(shoulder)
      raise ArgumentError, "curve must be within 0..1" unless (0.0..1.0).cover?(curve)

      w = width / 2.0
      h = height / 2.0
      ys = -h + height * shoulder
      p = ->(x, y) { center + Geometry::Point.new(x, y) }
      drop = curve * (h - ys)
      reach = curve * w
      segments = [
        Geometry::Line.new(p.(-w, -h), p.(w, -h)),
        Geometry::Line.new(p.(w, -h), p.(w, ys)),
        Geometry::Cubic.new(p.(w, ys), p.(w, ys + drop), p.(reach, h), p.(0.0, h)),
        Geometry::Cubic.new(p.(0.0, h), p.(-reach, h), p.(-w, ys + drop), p.(-w, ys)),
        Geometry::Line.new(p.(-w, ys), p.(-w, -h))
      ].reject { |s| s.is_a?(Geometry::Line) && s.length < 1e-9 }
      Geometry::Path.new([Geometry::Path::Subpath.new(segments: segments, closed: true)])
    end

    def polygon(center, points)
      Geometry::Path.polyline(points.map { |x, y| center + Geometry::Point.new(x, y) }, closed: true)
    end
    private_class_method :polygon
  end
end
