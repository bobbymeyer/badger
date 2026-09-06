# frozen_string_literal: true

module Badger
  module Geometry
    # A curve addressed by arc length. Built from one or more pieces laid end
    # to end; closed spines wrap, open spines clamp. Every query takes a
    # distance s along the curve and answers with geometry at that point.
    class Spine
      EPSILON = 1e-9

      # Everything a glyph needs to sit on the spine at one arc length:
      # the point, the unit tangent (reading direction), the unit normal
      # (glyph "up"), and the arc length itself.
      Placement = Data.define(:point, :tangent, :normal, :length) do
        def angle = tangent.angle
        def degrees = angle * 180.0 / Math::PI
      end

      attr_reader :pieces, :corner_threshold

      # corner_threshold: tangent discontinuity, in degrees, above which a
      # junction between pieces counts as a corner.
      def initialize(pieces, closed: false, corner_threshold: 15.0)
        raise ArgumentError, "a spine needs at least one piece" if pieces.empty?

        @pieces = pieces.freeze
        @closed = closed
        @corner_threshold = corner_threshold
        @tables = pieces.map(&:arc_length_table)
        @offsets = @tables.each_with_object([0.0]) { |table, acc| acc << acc.last + table.length }
      end

      def inspect
        "#<#{self.class.name} #{closed? ? 'closed' : 'open'} length=#{Geometry.fmt(length)} pieces=#{pieces.size}>"
      end

      def closed? = @closed
      def open? = !@closed
      def length = @offsets.last
      def start_point = pieces.first.start_point
      def end_point = pieces.last.end_point

      # Wrap (closed) or clamp (open) an arc length into range.
      def normalize(s)
        if closed?
          s % length
        else
          s.clamp(0.0, length)
        end
      end

      # [piece index, local parameter] for an arc length.
      def locate(s)
        s = normalize(s)
        i = @offsets.each_index.reverse_each.find { |k| k < pieces.size && @offsets[k] <= s } || 0
        [i, @tables[i].param_at(s - @offsets[i])]
      end

      def at(s)
        i, t = locate(s)
        piece = pieces[i]
        tangent = tangent_near(piece, t).normalized
        Placement.new(point: piece.point(t), tangent: tangent, normal: tangent.perp, length: normalize(s))
      end

      def point_at(s) = at(s).point
      def tangent_at(s) = at(s).tangent
      def normal_at(s) = at(s).normal

      # Arc length from the start of the spine to parameter t of piece i.
      def length_at(piece_index, t) = @offsets[piece_index] + @tables[piece_index].length_at(t)

      # Arc lengths where consecutive pieces meet at an angle above the
      # threshold. A glyph whose extent spans one of these will tear.
      def corners
        @corners ||= begin
          found = []
          pieces.each_cons(2).with_index(1) do |(a, b), i|
            found << @offsets[i] if corner?(a.end_tangent, b.start_tangent)
          end
          found.unshift(0.0) if closed? && corner?(pieces.last.end_tangent, pieces.first.start_tangent)
          found
        end
      end

      # Whether any corner lies strictly inside the arc-length interval (s0, s1).
      def corner_between?(s0, s1)
        return false if corners.empty? || s1 <= s0
        return corners.any? { |k| k > s0 + EPSILON && k < s1 - EPSILON } if open?
        return true if s1 - s0 >= length

        a = normalize(s0)
        b = normalize(s1)
        if a <= b
          corners.any? { |k| k > a + EPSILON && k < b - EPSILON }
        else
          corners.any? { |k| k > a + EPSILON || k < b - EPSILON }
        end
      end

      # `count` points spaced by equal arc length. Closed spines omit the
      # repeated start; open spines include both ends.
      def sample(count)
        raise ArgumentError, "count must be positive" unless count.positive?

        if closed?
          Array.new(count) { |i| point_at(length * i / count.to_f) }
        elsif count == 1
          [start_point]
        else
          Array.new(count) { |i| point_at(length * i / (count - 1.0)) }
        end
      end

      def reversed
        Spine.new(pieces.reverse.map(&:reversed), closed: closed?, corner_threshold: corner_threshold)
      end

      # The run a line of type takes across the top or bottom of a closed
      # spine, reading left to right: from the leftmost point to the
      # rightmost point by way of that side.
      Sweep = Data.define(:spine, :start, :length) do
        def end = start + length
      end

      def sweep(side, samples: 720)
        raise ArgumentError, "sweep is :top or :bottom" unless %i[top bottom].include?(side)
        raise ArgumentError, "a sweep needs a closed spine" unless closed?

        points = Array.new(samples) { |i| [length * i / samples.to_f, point_at(length * i / samples.to_f)] }
        upper = side == :top
        left = points.min_by { |_, p| [p.x, upper ? p.y : -p.y] }
        right = points.min_by { |_, p| [-p.x, upper ? p.y : -p.y] }
        forward_length = (right[0] - left[0]) % length
        forward_mid = point_at(left[0] + forward_length / 2)
        centre_y = (points.map { |_, p| p.y }.min + points.map { |_, p| p.y }.max) / 2
        forward_is_that_side = upper ? forward_mid.y < centre_y : forward_mid.y > centre_y

        if forward_is_that_side
          Sweep.new(spine: self, start: left[0], length: forward_length)
        else
          Sweep.new(spine: reversed, start: (length - left[0]) % length, length: length - forward_length)
        end
      end

      # Polyline with every vertex on the curve; a closed spine does not
      # repeat its first vertex at the end.
      def flatten(tolerance = 0.25)
        points = []
        pieces.each do |piece|
          piece.flatten(tolerance).each do |p|
            points << p unless points.last&.approx?(p, EPSILON)
          end
        end
        points.pop if closed? && points.size > 1 && points.first.approx?(points.last, EPSILON)
        points
      end

      def offset(distance, tolerance: 0.25) = Offset.spine(self, distance, tolerance: tolerance)

      def to_path(tolerance: 0.25)
        segments = pieces.flat_map do |piece|
          case piece
          when Line, Cubic then [piece]
          when Ellipse then piece.to_cubics
          end
        end
        if segments.all?
          Path.new([Path::Subpath.new(segments: segments, closed: closed?)])
        else
          Path.polyline(flatten(tolerance), closed: closed?)
        end
      end

      private

      # Cusps (zero derivative) get nudged so the tangent is still defined.
      def tangent_near(piece, t)
        tangent = piece.derivative(t)
        return tangent if tangent.length > 1e-12

        [t + 1e-6, t - 1e-6].map { |u| piece.derivative(u.clamp(0.0, 1.0)) }.max_by(&:length)
      end

      def corner?(out_tangent, in_tangent)
        return false if out_tangent.length < 1e-12 || in_tangent.length < 1e-12

        cosine = (out_tangent.dot(in_tangent) / (out_tangent.length * in_tangent.length)).clamp(-1.0, 1.0)
        Math.acos(cosine) * 180.0 / Math::PI > corner_threshold
      end
    end
  end
end
