# frozen_string_literal: true

module Badger
  # Plain geometry: points, curve pieces, arc-length tables, spines, paths and
  # offsets. Nothing in here knows about fonts or containers.
  module Geometry
    TAU = 2 * Math::PI

    # Format a coordinate for SVG output: four decimals, trailing zeros removed.
    def self.fmt(number)
      s = format("%.4f", number)
      s = s.sub(/\.?0+\z/, "") if s.include?(".")
      s == "-0" ? "0" : s
    end
  end
end

require_relative "geometry/point"
require_relative "geometry/affine"
require_relative "geometry/quadrature"
require_relative "geometry/arc_length_table"
require_relative "geometry/piece"
require_relative "geometry/line"
require_relative "geometry/cubic"
require_relative "geometry/ellipse"
require_relative "geometry/spine"
require_relative "geometry/path"
require_relative "geometry/svg_path_parser"
require_relative "geometry/offset"
