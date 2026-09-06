# frozen_string_literal: true

module Badger
  # A stack of lines with a union scope. Lines are anything with a path
  # (Settings, Follows, bare Paths), already positioned; `stack` positions
  # Settings for you, on ink bounds rather than font metrics.
  #
  #   :line   each line gets its own outline; touching lines show a seam
  #   :block  one continuous outline around the whole stack: the patch look,
  #           which also absorbs collisions from tight leading
  #
  # Union the glyph outlines before any offset or boolean: skipping it is
  # the source of nearly every interior seam artifact.
  class Block
    SCOPES = %i[line block].freeze

    attr_reader :lines, :union

    def initialize(lines, union: :line)
      raise ArgumentError, "union must be :line or :block" unless SCOPES.include?(union)
      raise ArgumentError, "a block needs at least one line" if lines.empty?

      @lines = lines.freeze
      @union = union
    end

    # Stack Settings vertically on ink bounds: each line's ink top sits
    # `gap` below the previous line's ink bottom. Horizontal alignment is
    # on ink too. The first line's baseline stays at y = 0.
    def self.stack(settings, gap:, align: :center, union: :line)
      raise ArgumentError, "align must be :left, :center or :right" unless %i[left center right].include?(align)

      widest = settings.map { |s| s.ink_bounds.then { |a, b| b.x - a.x } }.max
      bottom = nil
      placed = settings.map do |setting|
        min, max = setting.ink_bounds
        dy = bottom ? bottom + gap - min.y : 0.0
        dx = case align
             when :left then -min.x
             when :center then -(min.x + max.x) / 2
             when :right then widest - max.x
             end
        bottom = max.y + dy
        setting.transform(Geometry::Affine.translate(dx, dy))
      end
      new(placed, union: union)
    end

    def line_paths = lines.map { |line| line.is_a?(Geometry::Path) ? line : line.path }

    # The unioned outlines: one Path per line, or one Path for the block.
    def paths
      @paths ||= case union
                 when :line then line_paths.map { |p| Booleans.union(p) }
                 when :block then [Booleans.union(line_paths)]
                 end
    end

    def path = paths.reduce(Geometry::Path.new([]), :+)
    def bounds(tolerance: 0.1) = raw_path.bounds(tolerance: tolerance)
    def ink_bounds(tolerance: 0.1) = bounds(tolerance: tolerance)

    # The lines' outlines before union, for anything that does not need it.
    def raw_path = line_paths.reduce(Geometry::Path.new([]), :+)
  end
end
