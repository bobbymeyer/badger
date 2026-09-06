# frozen_string_literal: true

module Badger
  module Geometry
    class Line
      include Piece

      attr_reader :p0, :p1

      def initialize(p0, p1)
        @p0 = p0
        @p1 = p1
      end

      def point(t) = p0.lerp(p1, t)
      def derivative(_t = 0.0) = p1 - p0
      def length = p0.distance_to(p1)
      def table_resolution = 1
      def flatten(_tolerance = nil) = [p0, p1]
      def reversed = Line.new(p1, p0)

      def to_d = "L #{Geometry.fmt(p1.x)} #{Geometry.fmt(p1.y)}"
      def ==(other) = other.is_a?(Line) && p0 == other.p0 && p1 == other.p1
    end
  end
end
