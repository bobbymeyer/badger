# frozen_string_literal: true

module Badger
  # Follow mode: distributes a run of advances (glyph widths, in the spine's
  # units) along a spine by arc length, with uniform tracking between them.
  # Each placement carries the point and tangent at the glyph's advance
  # centre, so the glyph is rotated about its middle and straddles the curve
  # evenly.
  #
  # Given a shaped Run instead of bare advances, `path` returns the glyph
  # outlines transformed onto the spine.
  class Follow
    ALIGNMENTS = %i[start center end justify].freeze

    Placement = Data.define(:index, :advance, :start, :center, :end, :point, :tangent, :normal,
                            :straddles_corner) do
      def angle = tangent.angle
      def degrees = angle * 180.0 / Math::PI
      def straddles_corner? = straddles_corner

      # Maps a glyph drawn with its origin at (0, 0) and its advance along +x
      # onto the spine, centred on its advance.
      def affine
        Geometry::Affine.translate(point.x, point.y) * Geometry::Affine.rotate(angle) *
          Geometry::Affine.translate(-advance / 2.0, 0)
      end

      def svg_transform
        f = Geometry.method(:fmt)
        "translate(#{f.(point.x)} #{f.(point.y)}) rotate(#{f.(degrees)}) translate(#{f.(-advance / 2.0)} 0)"
      end
    end

    attr_reader :spine, :run, :advances, :tracking, :start, :sweep, :align

    # start:  arc length where the sweep begins
    # sweep:  arc length available to the run; defaults to the whole closed
    #         spine, or the remainder of an open one
    # align:  :start, :center, :end place the run within the sweep at the
    #         given tracking; :justify solves tracking so the run fills it
    def initialize(spine, advances_or_run, tracking: 0.0, start: 0.0, sweep: nil, align: :start)
      raise ArgumentError, "align must be one of #{ALIGNMENTS.join(', ')}" unless ALIGNMENTS.include?(align)

      @spine = spine
      @run = advances_or_run if advances_or_run.respond_to?(:glyphs)
      @advances = (run ? run.advances : advances_or_run).map(&:to_f).freeze
      @start = start.to_f
      @sweep = (sweep || (spine.closed? ? spine.length : spine.length - @start)).to_f
      @align = align
      @tracking = align == :justify ? Follow.tracking_to_sweep(@advances, @sweep) : tracking.to_f
    end

    # Tracking that makes a run of advances exactly fill a sweep.
    def self.tracking_to_sweep(advances, sweep)
      return 0.0 if advances.size < 2

      (sweep - advances.sum) / (advances.size - 1)
    end

    def run_length
      return 0.0 if advances.empty?

      advances.sum + (advances.size - 1) * tracking
    end

    def overflow = run_length - sweep
    def fits? = overflow <= 1e-9

    # Arc length where the first advance begins.
    def origin
      case align
      when :start, :justify then start
      when :center then start + (sweep - run_length) / 2.0
      when :end then start + sweep - run_length
      end
    end

    # Glyph outlines on the spine, one subpath per contour. Needs a Run.
    def path
      raise Badger::Error, "Follow#path needs a shaped Run, not bare advances" unless run

      subpaths = run.glyphs.zip(placements).flat_map do |glyph, placement|
        glyph.ink? ? glyph.path.transform(placement.affine).subpaths : []
      end
      Geometry::Path.new(subpaths)
    end

    def bounds(tolerance: 0.1) = path.bounds(tolerance: tolerance)

    def placements
      @placements ||= begin
        pen = origin
        advances.each_with_index.map do |advance, i|
          s0 = pen
          s1 = pen + advance
          at = spine.at((s0 + s1) / 2.0)
          pen = s1 + tracking
          Placement.new(index: i, advance: advance, start: s0, center: (s0 + s1) / 2.0, end: s1,
                        point: at.point, tangent: at.tangent, normal: at.normal,
                        straddles_corner: spine.corner_between?(s0, s1))
        end
      end
    end
  end
end
