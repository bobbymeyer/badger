# frozen_string_literal: true

module Badger
  module Geometry
    # Shared behaviour for anything a Spine can be built from. A piece is a
    # parametric curve over t in [0, 1] that answers point(t) and
    # derivative(t); everything else derives from those two.
    module Piece
      def start_point = point(0.0)
      def end_point = point(1.0)
      def start_tangent = derivative(0.0)
      def end_tangent = derivative(1.0)

      # Number of table intervals used by the arc-length table. Straight
      # pieces override this with 1; curved ones pick enough to keep the
      # linear interpolation inside Newton's basin of convergence.
      def table_resolution = 16

      def arc_length_table = (@arc_length_table ||= ArcLengthTable.new(self))
      def length = arc_length_table.length

      def reversed = Reversed.new(self)

      # Polyline approximation with every point on the curve and both ends
      # included. Subclasses with better knowledge of their own curvature
      # override this; the default samples uniformly in t.
      def flatten(_tolerance, samples = 32)
        (0..samples).map { |i| point(i.to_f / samples) }
      end
    end

    # A piece traversed backwards. Used for spines that read the other way
    # (the bottom arc of a badge) when the piece has no cheaper reversal.
    class Reversed
      include Piece

      attr_reader :inner

      def initialize(inner)
        @inner = inner
      end

      def point(t) = inner.point(1.0 - t)
      def derivative(t) = -inner.derivative(1.0 - t)
      def table_resolution = inner.table_resolution
      def flatten(tolerance) = inner.flatten(tolerance).reverse
      def reversed = inner
    end
  end
end
