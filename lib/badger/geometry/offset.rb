# frozen_string_literal: true

module Badger
  module Geometry
    # Parallel offset of a spine. The spine is flattened, each edge is shifted
    # along its normal, convex corners get round joins and concave corners
    # are mitred at the intersection of the neighbouring offset edges.
    #
    # Positive distance moves outward on a closed spine (whatever its
    # winding) and toward the "up" normal on an open one; negative moves the
    # other way. Self-intersections from large inward offsets are not
    # cleaned up; that is Clipper2's job once the geometry layer is chosen.
    module Offset
      EPSILON = 1e-9

      def self.path(spine, distance, tolerance: 0.25)
        Path.polyline(points(spine, distance, tolerance: tolerance), closed: spine.closed?)
      end

      def self.spine(spine, distance, tolerance: 0.25)
        path(spine, distance, tolerance: tolerance).spine(corner_threshold: spine.corner_threshold)
      end

      def self.points(spine, distance, tolerance: 0.25)
        vertices = spine.flatten(tolerance)
        return vertices if distance.zero?
        raise ArgumentError, "an offset needs at least two vertices" if vertices.size < 2

        closed = spine.closed?
        sign = closed && signed_area(vertices).negative? ? -1.0 : 1.0
        edge_count = closed ? vertices.size : vertices.size - 1
        directions = Array.new(edge_count) { |i| (vertices[(i + 1) % vertices.size] - vertices[i]).normalized }
        shifted = Array.new(edge_count) do |i|
          shift = directions[i].perp * (sign * distance)
          [vertices[i] + shift, vertices[(i + 1) % vertices.size] + shift]
        end

        out = []
        out << shifted.first[0] unless closed
        joins = closed ? (0...edge_count) : (1...edge_count)
        joins.each do |i|
          prev = (i - 1) % edge_count
          turn = directions[prev].cross(directions[i]) * sign * (distance.positive? ? 1 : -1)
          if turn > EPSILON
            out << shifted[prev][1]
            out.concat(round_join(vertices[i], shifted[prev][1], shifted[i][0], distance.abs, tolerance))
            out << shifted[i][0]
          elsif turn < -EPSILON
            out << (intersection(shifted[prev], shifted[i]) || shifted[i][0])
          else
            out << shifted[i][0]
          end
        end
        out << shifted.last[1] unless closed
        out.each_with_object([]) { |p, acc| acc << p unless acc.last&.approx?(p, EPSILON) }
      end

      def self.signed_area(points)
        points.each_index.sum do |i|
          a = points[i]
          b = points[(i + 1) % points.size]
          a.x * b.y - b.x * a.y
        end / 2.0
      end

      # Intermediate arc points from `from` to `to` around `center`.
      def self.round_join(center, from, to, radius, tolerance)
        a0 = (from - center).angle
        a1 = (to - center).angle
        delta = a1 - a0
        delta -= TAU while delta > Math::PI
        delta += TAU while delta < -Math::PI
        step = tolerance >= radius ? Math::PI / 2 : 2 * Math.acos(1 - tolerance / radius)
        steps = [(delta.abs / step).ceil, 1].max
        (1...steps).map { |k| center + Point.new(Math.cos(a0 + delta * k / steps), Math.sin(a0 + delta * k / steps)) * radius }
      end

      def self.intersection(edge_a, edge_b)
        a, b = edge_a
        c, d = edge_b
        ab = b - a
        cd = d - c
        denominator = ab.cross(cd)
        return nil if denominator.abs < 1e-12

        t = (c - a).cross(cd) / denominator
        a + ab * t
      end
    end
  end
end
