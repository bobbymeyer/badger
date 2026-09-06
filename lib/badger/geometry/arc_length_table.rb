# frozen_string_literal: true

module Badger
  module Geometry
    # Numeric arc-length parameterization of a single curve piece over
    # t in [0, 1]. Builds a cumulative-length table at `resolution` evenly
    # spaced parameter values, then answers both directions:
    #
    #   length_at(t)  - arc length from the start of the piece to parameter t
    #   param_at(s)   - the parameter t at which arc length s is reached
    #
    # The inverse lookup binary-searches the table for the bracketing
    # interval, interpolates linearly, then polishes with Newton steps on
    # the exact quadrature so the answer is not limited by table density.
    class ArcLengthTable
      NEWTON_STEPS = 4
      NEWTON_TOLERANCE = 1e-10

      attr_reader :piece, :resolution

      def initialize(piece, resolution = piece.table_resolution)
        raise ArgumentError, "resolution must be positive" unless resolution.positive?

        @piece = piece
        @resolution = resolution
        @cumulative = build_table
      end

      def length = @cumulative.last

      def length_at(t)
        return 0.0 if t <= 0.0
        return length if t >= 1.0

        k = [(t * resolution).floor, resolution - 1].min
        @cumulative[k] + Quadrature.length(piece, k.to_f / resolution, t)
      end

      def param_at(s)
        return 0.0 if s <= 0.0
        return 1.0 if s >= length

        k = (0...resolution).bsearch { |i| @cumulative[i + 1] >= s } || resolution - 1
        lo = k.to_f / resolution
        hi = (k + 1).to_f / resolution
        span = @cumulative[k + 1] - @cumulative[k]
        t = span.positive? ? lo + (s - @cumulative[k]) / span * (hi - lo) : lo

        NEWTON_STEPS.times do
          error = @cumulative[k] + Quadrature.length(piece, lo, t) - s
          break if error.abs < NEWTON_TOLERANCE

          speed = piece.derivative(t).length
          break if speed < 1e-12

          t = (t - error / speed).clamp(lo, hi)
        end
        t
      end

      private

      def build_table
        table = [0.0]
        resolution.times do |k|
          table << table.last + Quadrature.length(piece, k.to_f / resolution, (k + 1).to_f / resolution)
        end
        table
      end
    end
  end
end
