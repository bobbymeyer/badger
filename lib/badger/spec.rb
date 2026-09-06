# frozen_string_literal: true

module Badger
  # A badge as a document: the container tree, its regions, its type and
  # its artwork, with every parameter named for what it means. This is what
  # the engine stores and what the API takes; Spec.build turns it into the
  # container tree the core renders.
  #
  #   name: Stockholm Stadion
  #   shape: { kind: ellipse, rx: 260, ry: 170 }
  #   regions:
  #     - { kind: rule, distance: 0, weight: 5 }
  #     - { kind: band, name: ring, outer: -8, width: 40 }
  #     - { kind: interior, name: field, inside: -52 }
  #   type:
  #     - { mode: follow, text: STOCKHOLM STADION, font: Archivo-Bold, region: ring,
  #         inset: 7, sweep: top, align: justify }
  #     - { mode: follow, text: "1912", font: Archivo-Bold, region: ring, from: outer,
  #         inset: 7, sweep: bottom, align: center, tracking: 10 }
  #     - { mode: fit, text: S, font: Archivo-Bold, region: field, fit: chord_at_x, at: 0, inset: 8 }
  #     - { mode: fixed, text: EST. 1912, font: Archivo, size: 15,
  #         at: { polar: { angle: 90, radius: 120 } }, align: top }
  #   illustrations:
  #     - { svg: "<svg>...</svg>", at: centroid, fit: { width: 80, height: 80 } }
  #   children:
  #     - { name: medallion, shape: { kind: circle, radius: 58 }, at: centroid, regions: [...], type: [...] }
  class Spec
    class Error < Badger::Error; end

    SHAPES = %w[circle ellipse rectangle lozenge rounded_rectangle shield superellipse path].freeze
    REGIONS = %w[rule band interior].freeze
    MODES = %w[follow fit fixed].freeze
    FITS = %w[chord_at_y chord_at_x chord_at_x_per_glyph box].freeze
    SWEEPS = %w[top bottom full].freeze

    def self.build(document, **options) = new(document, **options).container

    attr_reader :document

    # fonts: anything answering font(name) with a Badger::Font; base_dir:
    # where an illustration's `file:` is relative to.
    def initialize(document, fonts: Fonts, base_dir: nil)
      @document = normalize(document)
      @fonts = fonts
      @base_dir = base_dir
    end

    def container = @container ||= build_container(document, "badge")

    private

    def normalize(value)
      case value
      when Hash then value.to_h { |k, v| [k.to_s, normalize(v)] }
      when Array then value.map { |v| normalize(v) }
      else value
      end
    end

    def error(message, where) = raise(Error, "#{where}: #{message}")

    def fetch(doc, key, where, default = :required)
      return doc[key] if doc.key?(key)
      return default unless default == :required

      error("needs #{key}", where)
    end

    def number(doc, key, where, default = :required)
      value = fetch(doc, key, where, default)
      return value if value.nil? && default.nil?
      error("#{key} must be a number", where) unless value.is_a?(Numeric)

      value.to_f
    end

    def one_of(doc, key, where, allowed, default = :required)
      value = fetch(doc, key, where, default).to_s
      error("#{key} must be one of #{allowed.join(', ')}", where) unless allowed.include?(value)
      value
    end

    # --- containers -----------------------------------------------------------

    def build_container(doc, where)
      error("must be a mapping", where) unless doc.is_a?(Hash)

      shape = build_shape(fetch(doc, "shape", where), "#{where}.shape")
      container = Container.new(shape, visible: doc.fetch("visible", true), name: doc["name"],
                                slot: slot_of(doc, where, :ground), tolerance: number(doc, "tolerance", where, 0.1))
      outer = @current
      @current = container
      regions = {}
      Array(doc["regions"]).each_with_index do |r, i|
        region = build_region(container, r, "#{where}.regions[#{i}]")
        regions[r["name"].to_s] = region if r["name"]
      end
      Array(doc["type"]).each_with_index { |t, i| build_type(container, regions, t, "#{where}.type[#{i}]") }
      Array(doc["illustrations"]).each_with_index { |a, i| build_illustration(container, a, "#{where}.illustrations[#{i}]") }
      Array(doc["children"]).each_with_index do |c, i|
        child_where = "#{where}.children[#{i}]"
        child = build_container(c, child_where)
        place(container, child, c, child_where, name: c["name"], slot: slot_of(c, child_where, :ground))
      end
      container
    ensure
      @current = outer
    end

    def build_shape(doc, where)
      error("must be a mapping with a kind", where) unless doc.is_a?(Hash)

      case one_of(doc, "kind", where, SHAPES)
      when "circle" then Shapes.circle(number(doc, "radius", where))
      when "ellipse" then Shapes.ellipse(number(doc, "rx", where), number(doc, "ry", where),
                                         rotation: number(doc, "rotation", where, 0.0) * Math::PI / 180)
      when "rectangle" then Shapes.rectangle(number(doc, "width", where), number(doc, "height", where))
      when "lozenge"
        Shapes.lozenge(number(doc, "width", where), number(doc, "height", where), radius: number(doc, "radius", where, 0.0))
      when "superellipse"
        Shapes.superellipse(number(doc, "width", where), number(doc, "height", where), exponent: number(doc, "exponent", where, 2.5))
      when "rounded_rectangle"
        Shapes.rounded_rectangle(number(doc, "width", where), number(doc, "height", where), radius: number(doc, "radius", where))
      when "shield"
        Shapes.shield(number(doc, "width", where), number(doc, "height", where),
                      shoulder: number(doc, "shoulder", where, 0.4), curve: number(doc, "curve", where, 0.55))
      when "path" then Geometry::Path.parse(fetch(doc, "d", where).to_s)
      end
    rescue ArgumentError => e
      error(e.message, where)
    end

    def build_region(container, doc, where)
      error("must be a mapping with a kind", where) unless doc.is_a?(Hash)

      case one_of(doc, "kind", where, REGIONS)
      when "rule"
        container.rule(number(doc, "distance", where), weight: number(doc, "weight", where, 2.0),
                       visible: doc.fetch("visible", true), name: doc["name"], slot: slot_of(doc, where, :ink))
      when "band"
        container.band(outer: number(doc, "outer", where), inner: number(doc, "inner", where, nil),
                       width: number(doc, "width", where, nil), visible: doc.fetch("visible", false),
                       name: doc["name"], slot: slot_of(doc, where, :field))
      when "interior"
        container.interior(inside: number(doc, "inside", where, 0.0), visible: doc.fetch("visible", false),
                           name: doc["name"], slot: slot_of(doc, where, :field))
      end
    rescue ArgumentError => e
      error(e.message, where)
    end

    # --- type -----------------------------------------------------------------

    def build_type(container, regions, doc, where)
      error("must be a mapping with a mode", where) unless doc.is_a?(Hash)

      case one_of(doc, "mode", where, MODES)
      when "follow" then build_follow(container, regions, doc, where)
      when "fit" then build_fit(container, regions, doc, where)
      when "fixed" then build_fixed(container, doc, where)
      end
    rescue ArgumentError, Badger::Error => e
      raise if e.is_a?(Error)

      error(e.message, where)
    end

    def shape_text(doc, where, size)
      text = fetch(doc, "text", where).to_s
      font = @fonts.font(fetch(doc, "font", where))
      font.shape(text, size: size, features: symbolize(doc["features"]), variations: symbolize(doc["variations"]),
                 pair_overrides: doc["pair_overrides"] || {})
    rescue Fonts::Unknown => e
      error(e.message, where)
    end

    def symbolize(hash) = (hash || {}).to_h { |k, v| [k.to_sym, v] }

    def band_named(regions, doc, where)
      name = fetch(doc, "region", where).to_s
      region = regions[name] or error("names region #{name.inspect}, which is not defined", where)
      error("region #{name.inspect} is not a band", where) unless region.is_a?(Regions::Band)
      region
    end

    def build_follow(container, regions, doc, where)
      band = band_named(regions, doc, where)
      inset = number(doc, "inset", where, 0.0)
      from = one_of(doc, "from", where, %w[inner outer], "inner").to_sym
      size = number(doc, "size", where, nil)
      run = if size
              shape_text(doc, where, size)
            else
              policy = doc["max_size"] ? :contain : :fill
              Fit.new(policy: policy, max_size: number(doc, "max_size", where, nil))
                 .to_band(shape_text(doc, where, 100), band, inset: number(doc, "band_inset", where, inset)).run
            end
      baseline = band.baseline(inset, from: from)
      spine, start, length = sweep_of(baseline, doc, where)
      align = one_of(doc, "align", where, Follow::ALIGNMENTS.map(&:to_s), "center").to_sym
      follow = Follow.new(spine, run, tracking: number(doc, "tracking", where, 0.0), start: start, sweep: length, align: align)
      container.attach(follow, name: doc["name"] || run.text, slot: slot_of(doc, where, :ink))
    end

    def sweep_of(baseline, doc, where)
      sweep = doc.fetch("sweep", "top")
      case sweep
      when "top", "bottom"
        s = baseline.sweep(sweep.to_sym)
        s = Geometry::Spine::Sweep.new(spine: s.spine.reversed, start: baseline.length - s.end, length: s.length) if doc["reversed"]
        [s.spine, s.start, s.length]
      when "full"
        spine = doc["reversed"] ? baseline.reversed : baseline
        [spine, number(doc, "start", where, 0.0) * spine.length, spine.length]
      when Hash
        spine = doc["reversed"] ? baseline.reversed : baseline
        if sweep.key?("from") || sweep.key?("to")
          # visual degrees from the container's centroid, clockwise on screen;
          # the run goes from `from` to `to` in the spine's direction
          center = @current.centroid
          from = spine.length_at_angle(number(sweep, "from", "#{where}.sweep") * Math::PI / 180, center: center)
          to = spine.length_at_angle(number(sweep, "to", "#{where}.sweep") * Math::PI / 180, center: center)
          [spine, from, (to - from) % spine.length]
        else
          start = number(sweep, "start", "#{where}.sweep") * spine.length
          length = number(sweep, "length", "#{where}.sweep") * spine.length
          [spine, start, length]
        end
      else
        error("sweep must be top, bottom, full, { start:, length: } as fractions or { from:, to: } in degrees", where)
      end
    end

    def interior_named(container, regions, doc, where)
      return container.interior(inside: 0.0) unless doc["region"]

      name = doc["region"].to_s
      region = regions[name] or error("names region #{name.inspect}, which is not defined", where)
      error("region #{name.inspect} is not an interior", where) unless region.is_a?(Regions::Interior)
      region
    end

    def build_fit(container, regions, doc, where)
      fit_kind = one_of(doc, "fit", where, FITS, "chord_at_y")
      policy = doc["max_size"] ? :contain : one_of(doc, "policy", where, %w[fill contain fixed], "fill").to_sym
      error("policy contain needs max_size", where) if policy == :contain && doc["max_size"].nil?
      run = shape_text(doc, where, number(doc, "size", where, 100.0))
      slot = slot_of(doc, where, :ink)
      name = doc["name"] || run.text

      stretch = doc["stretch"] && (number(doc["stretch"], "min", "#{where}.stretch")..number(doc["stretch"], "max", "#{where}.stretch"))
      if fit_kind == "box"
        axes = one_of(doc, "axes", where, %w[width height both], "width").to_sym
        fit = Fit.new(policy: policy, axes: axes, max_size: number(doc, "max_size", where, nil), stretch: stretch)
        result = fit.to_box(run, width: number(doc, "width", where, nil), height: number(doc, "height", where, nil))
        setting = Setting.new(result.run, Geometry::Affine.scale(1.0, result.stretch))
        place(container, setting, doc, where, name: name, slot: slot)
      elsif fit_kind == "chord_at_x_per_glyph"
        error("chord_at_x_per_glyph needs a stretch: { min:, max: } range", where) unless stretch
        fit = Fit.new(policy: :fill, axes: :both, stretch: stretch)
        interior = interior_named(container, regions, doc, where)
        block = fit.glyphs_to_chords_at_x(run, interior, y: number(doc, "at", where, 0.0), inset: number(doc, "inset", where, 0.0),
                                          word_inset: number(doc, "word_inset", where, 0.0), fill: number(doc, "fill", where, 1.0),
                                          edge: one_of(doc, "edge", where, %w[center narrowest], "center").to_sym,
                                          tracking: number(doc, "tracking", where, 0.0))
        container.attach(block, name: name, slot: slot)
      else
        across = fit_kind == "chord_at_y" ? number(doc, "height", where, nil) : number(doc, "width", where, nil)
        fit = if across
                error("a fixed #{fit_kind == 'chord_at_y' ? 'height' : 'width'} needs a stretch: { min:, max: } range", where) unless stretch
                Fit.new(policy: policy, axes: :both, max_size: number(doc, "max_size", where, nil), stretch: stretch)
              else
                Fit.new(policy: policy, max_size: number(doc, "max_size", where, nil))
              end
        interior = interior_named(container, regions, doc, where)
        options = { inset: number(doc, "inset", where, 0.0), fill: number(doc, "fill", where, 1.0),
                    anchor: one_of(doc, "anchor", where, %w[center baseline], "center").to_sym,
                    edge: one_of(doc, "edge", where, %w[center narrowest], "center").to_sym }
        at = number(doc, "at", where)
        setting = if fit_kind == "chord_at_y"
                    fit.to_chord_at_y(run, interior, at, height: across, **options)
                  else
                    fit.to_chord_at_x(run, interior, at, width: across, **options)
                  end
        container.attach(setting, name: name, slot: slot)
      end
    end

    def build_fixed(container, doc, where)
      run = shape_text(doc, where, number(doc, "size", where))
      place(container, Setting.new(run), doc, where, name: doc["name"] || run.text, slot: slot_of(doc, where, :ink))
    end

    # --- illustration ---------------------------------------------------------

    def build_illustration(container, doc, where)
      error("must be a mapping", where) unless doc.is_a?(Hash)

      art = if doc["svg"]
              Illustration.new(doc["svg"].to_s, name: doc["name"])
            elsif doc["file"]
              path = @base_dir ? File.expand_path(doc["file"].to_s, @base_dir) : doc["file"].to_s
              error("file #{path} not found", where) unless File.file?(path)
              Illustration.from_file(path, name: doc["name"])
            else
              error("needs svg: or file:", where)
            end
      art = art.scale_by(number(doc, "scale", where)) if doc["scale"]
      if doc["fit"].is_a?(Hash)
        fit = Fit.new(policy: :contain, max_size: 1)
        art = fit.to_box(art, width: number(doc["fit"], "width", "#{where}.fit", nil),
                              height: number(doc["fit"], "height", "#{where}.fit", nil)).run
      end
      place(container, art, doc, where, name: doc["name"] || "artwork", slot: slot_of(doc, where, :ink))
    rescue ArgumentError => e
      error(e.message, where)
    end

    # --- anchoring ------------------------------------------------------------

    def place(container, child, doc, where, name:, slot:)
      locator = locator_of(doc.fetch("at", "centroid"), where)
      align = doc.fetch("align", "center")
      align = align.is_a?(Array) ? align : align.to_sym
      rotate = doc["rotate"]
      rotate = rotate.to_sym if rotate.is_a?(String)
      container.place(child, at: locator, align: align, rotate: rotate, name: name, slot: slot)
    rescue ArgumentError => e
      error(e.message, where)
    end

    def locator_of(value, where)
      case value
      when "centroid", nil then Locator.centroid
      when Hash
        if value["polar"].is_a?(Hash)
          Locator.polar(angle: number(value["polar"], "angle", "#{where}.at.polar"), radius: number(value["polar"], "radius", "#{where}.at.polar"))
        elsif value["axial"].is_a?(Array) && value["axial"].size == 2
          Locator.axial(*value["axial"].map(&:to_f))
        elsif value.key?("on_path")
          on = value["on_path"]
          on.is_a?(Hash) ? Locator.on_path(fraction: on["fraction"]&.to_f, length: on["length"]&.to_f) : Locator.on_path(fraction: on.to_f)
        else
          error("at must be centroid, { polar: { angle:, radius: } }, { axial: [x, y] } or { on_path: fraction }", where)
        end
      else
        error("at must be centroid, { polar: { angle:, radius: } }, { axial: [x, y] } or { on_path: fraction }", where)
      end
    end

    def slot_of(doc, where, default)
      value = doc.fetch("slot", default)
      value = value.to_sym if value.is_a?(String)
      Slot.rank(value)
      value
    rescue ArgumentError => e
      error(e.message, where)
    end
  end
end
