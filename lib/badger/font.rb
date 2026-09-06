# frozen_string_literal: true

module Badger
  # A font file, shaped through the sidecar. Produces Runs: shaped text in
  # badge units, y down, ready to be fitted, followed or fixed.
  class Font
    attr_reader :path, :sidecar

    def initialize(path, sidecar: Badger.sidecar)
      raise ArgumentError, "font file not found: #{path}" unless File.file?(path)

      @path = File.expand_path(path)
      @sidecar = sidecar
      @outlines = {}
    end

    # size:           em size in badge units
    # features:       OpenType feature switches, e.g. { liga: false, kern: true }
    # variations:     variable axis coordinates, e.g. { wght: 700 }
    # pair_overrides: extra space between specific character pairs, in badge
    #                 units at `size`, e.g. { "AV" => -4, "LT" => -2 }. Hand-set
    #                 pairs win over the font's own kerning.
    def shape(text, size:, features: {}, variations: {}, pair_overrides: {}, **shaping)
      response = sidecar.shape(font: path, text: text, features: features, variations: variations, **shaping)
      scale = size.to_f / response["upem"]
      cache_outlines(response["outlines"], variations)

      glyphs = response["glyphs"].each_with_index.map do |g, i|
        next_cluster = response["glyphs"][i + 1]&.fetch("cluster") || text.length
        Glyph.new(
          gid: g["gid"], name: g["name"], text: text[g["cluster"]...next_cluster].to_s,
          advance: g["advance"] * scale, x_offset: g["x_offset"] * scale, y_offset: -g["y_offset"] * scale,
          outline: @outlines[[g["gid"], variations]].transform(Geometry::Affine.scale(scale, -scale))
        )
      end

      Run.new(glyphs: apply_pair_overrides(glyphs, pair_overrides), size: size.to_f, scale: scale,
              metrics: Metrics.new(ascender: response["ascender"] * scale,
                                   descender: response["descender"] * scale,
                                   cap_height: response["cap_height"]&.*(scale),
                                   x_height: response["x_height"]&.*(scale)))
    end

    Metrics = Data.define(:ascender, :descender, :cap_height, :x_height)

    private

    def cache_outlines(outlines, variations)
      outlines.each do |gid, d|
        key = [gid.to_i, variations]
        @outlines[key] ||= d.empty? ? Geometry::Path.new([]) : Geometry::Path.parse(d)
      end
    end

    def apply_pair_overrides(glyphs, overrides)
      return glyphs if overrides.empty?

      glyphs.each_cons(2).map.with_index do |(left, right), i|
        adjustment = overrides[left.text + right.text]
        adjustment ? left.with(advance: left.advance + adjustment) : left
      end + [glyphs.last].compact
    end
  end

  # One positioned glyph in a run. `outline` is in badge units, y down, with
  # the pen position at the origin; `advance` is how far the pen moves after
  # it, kerning and overrides included.
  Glyph = Data.define(:gid, :name, :text, :advance, :x_offset, :y_offset, :outline) do
    def path = outline.transform(Geometry::Affine.translate(x_offset, y_offset))
    def ink? = !outline.empty?
  end

  # A shaped line of text laid out straight along +x from the origin.
  class Run
    attr_reader :glyphs, :size, :scale, :metrics

    def initialize(glyphs:, size:, scale:, metrics:)
      @glyphs = glyphs.freeze
      @size = size
      @scale = scale
      @metrics = metrics
    end

    def advances = glyphs.map(&:advance)
    def width = advances.sum
    def cap_height = metrics.cap_height
    def x_height = metrics.x_height
    def text = glyphs.map(&:text).join

    # Pen position of each glyph when set straight.
    def pen_positions
      glyphs.each_with_object([0.0]) { |g, acc| acc << acc.last + g.advance }[0...-1]
    end

    # All outlines set straight, as one Path.
    def path
      subpaths = glyphs.zip(pen_positions).flat_map do |glyph, x|
        glyph.ink? ? glyph.path.transform(Geometry::Affine.translate(x, 0)).subpaths : []
      end
      Geometry::Path.new(subpaths)
    end

    # [min, max] of the ink when set straight. Nil for an all-space run.
    def ink_bounds(tolerance: 0.1)
      p = path
      p.empty? ? nil : p.bounds(tolerance: tolerance)
    end
  end
end
