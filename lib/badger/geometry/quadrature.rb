# frozen_string_literal: true

module Badger
  module Geometry
    # Eight-point Gauss-Legendre quadrature of a curve's speed, which gives
    # the arc length between two parameter values. Exact for polynomials up
    # to degree 15, so a cubic's speed (square root of a quartic) integrates
    # to well below 1e-9 relative error once the interval is subdivided.
    module Quadrature
      NODES = [
        -0.9602898564975363, -0.7966664774136267, -0.5255324099163290, -0.1834346424956498,
        0.1834346424956498, 0.5255324099163290, 0.7966664774136267, 0.9602898564975363
      ].freeze

      WEIGHTS = [
        0.1012285362903763, 0.2223810344533745, 0.3137066458778873, 0.3626837833783620,
        0.3626837833783620, 0.3137066458778873, 0.2223810344533745, 0.1012285362903763
      ].freeze

      # Arc length of `curve` (anything responding to derivative(t)) from t0 to t1.
      def self.length(curve, t0, t1)
        half = (t1 - t0) / 2.0
        mid = (t0 + t1) / 2.0
        sum = 0.0
        NODES.each_with_index do |node, i|
          sum += WEIGHTS[i] * curve.derivative(mid + half * node).length
        end
        sum * half
      end
    end
  end
end
