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

    # A diamond: the points sit on the axes. `radius:` fillets the points.
    def lozenge(width, height, radius: 0.0, center: Geometry::Point.new(0.0, 0.0))
      corners = [[0.0, -height / 2.0], [width / 2.0, 0.0], [0.0, height / 2.0], [-width / 2.0, 0.0]]
      return polygon(center, corners) unless radius.positive?

      fillet(corners.map { |x, y| center + Geometry::Point.new(x, y) }, radius)
    end

    # |x/a|^n + |y/b|^n = 1: the oval between an ellipse (n = 2) and a
    # rounded rectangle, which is what many period badges actually are.
    # Sampled by arc angle into a closed polyline dense enough to be smooth.
    def superellipse(width, height, exponent: 2.5, center: Geometry::Point.new(0.0, 0.0), samples: 256)
      raise ArgumentError, "exponent must be positive" unless exponent.positive?

      a = width / 2.0
      b = height / 2.0
      k = 2.0 / exponent
      points = Array.new(samples) do |i|
        t = TAU * i / samples
        c = Math.cos(t)
        s = Math.sin(t)
        center + Geometry::Point.new(a * c.abs**k * (c <=> 0), b * s.abs**k * (s <=> 0))
      end
      Geometry::Path.polyline(points, closed: true)
    end

    # Round every corner of a closed polygon with an arc of `radius`, capped
    # so the arc never eats more than half an edge.
    def fillet(points, radius)
      n = points.size
      segments = []
      tangents = points.each_index.map do |i|
        prev = points[(i - 1) % n]
        this = points[i]
        nxt = points[(i + 1) % n]
        into = (this - prev).normalized
        out = (nxt - this).normalized
        turn = Math.acos((-into).dot(out).clamp(-1.0, 1.0)) # interior angle
        distance = radius / Math.tan(turn / 2)
        cap = [this.distance_to(prev), this.distance_to(nxt)].min / 2.0
        distance = [distance, cap].min
        [this - into * distance, this + out * distance, this]
      end
      tangents.each_with_index do |(a, b, corner), i|
        interior = Math.acos(((points[(i - 1) % n] - corner).normalized.dot((points[(i + 1) % n] - corner).normalized)).clamp(-1.0, 1.0))
        arc_angle = Math::PI - interior
        # the arc's radius as actually cut, which the edge-length cap may have reduced
        cut = corner.distance_to(a) * Math.tan(interior / 2)
        handle = 4.0 / 3 * Math.tan(arc_angle / 4) * cut
        c1 = a + (corner - a).normalized * handle
        c2 = b + (corner - b).normalized * handle
        segments << Geometry::Cubic.new(a, c1, c2, b)
        next_a = tangents[(i + 1) % n][0]
        segments << Geometry::Line.new(b, next_a) if b.distance_to(next_a) > 1e-9
      end
      Geometry::Path.new([Geometry::Path::Subpath.new(segments: segments, closed: true)])
    end

    TAU = Geometry::TAU

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
