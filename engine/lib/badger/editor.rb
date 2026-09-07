# What the editor's inspector is built from: for every kind of entry a
# document can hold, the fields it takes, named for what they mean, with the
# choices the core allows. The vocabulary is Badger::Spec's; this says how
# to ask for it. The view hands it to the editor as JSON, and the editor
# builds a field for each entry from it.
#
#   key      where in the entry the value lives, dotted for nesting
#   type     text, number, select, toggle, textarea, font, region, locator,
#            align, sweep, stretch
#   options  for a select, [value, label] pairs
#   when     a condition on another key: { key:, in: [...] }
module Badger
  module Editor
    module_function

    SLOTS = [ %w[ground ground], %w[field field], %w[ink ink] ].freeze
    ALIGNS = %w[center top bottom left right top_left top_right bottom_left bottom_right].freeze

    def field(key, label, type = "number", **options) = { key: key, label: label, type: type }.merge(options)

    def placement
      [
        field("at", "Placed at", "locator", hint: "A point in the parent: its centroid, a polar angle and radius, a fraction of its bounds, or a point along its path."),
        field("align", "Aligned by", "align", hint: "Which of the child's nine reference points lands on that point."),
        field("rotate", "Rotated", "number", step: 1, unit: "°", optional: true, hint: "Degrees about the reference point; blank for none.")
      ]
    end

    def shape_fields
      [
        field("shape.kind", "Shape", "select", options: Badger::Spec::SHAPES.map { |k| [ k, k.humanize ] }),
        field("shape.radius", "Radius", "number", step: 1, when: { key: "shape.kind", in: %w[circle] }),
        field("shape.rx", "Radius across", "number", step: 1, when: { key: "shape.kind", in: %w[ellipse] }),
        field("shape.ry", "Radius down", "number", step: 1, when: { key: "shape.kind", in: %w[ellipse] }),
        field("shape.rotation", "Rotation", "number", step: 1, unit: "°", optional: true, when: { key: "shape.kind", in: %w[ellipse] }),
        field("shape.width", "Width", "number", step: 1, when: { key: "shape.kind", in: %w[rectangle lozenge rounded_rectangle superellipse shield] }),
        field("shape.height", "Height", "number", step: 1, when: { key: "shape.kind", in: %w[rectangle lozenge rounded_rectangle superellipse shield] }),
        field("shape.radius", "Corner radius", "number", step: 1, optional: true, when: { key: "shape.kind", in: %w[lozenge] }),
        field("shape.radius", "Corner radius", "number", step: 1, when: { key: "shape.kind", in: %w[rounded_rectangle] }),
        field("shape.exponent", "Exponent", "number", step: 0.1, optional: true, when: { key: "shape.kind", in: %w[superellipse] },
              hint: "2 is an ellipse; higher is squarer."),
        field("shape.shoulder", "Shoulder", "number", step: 0.05, optional: true, when: { key: "shape.kind", in: %w[shield] }),
        field("shape.curve", "Curve", "number", step: 0.05, optional: true, when: { key: "shape.kind", in: %w[shield] }),
        field("shape.d", "Path", "textarea", when: { key: "shape.kind", in: %w[path] }, hint: "SVG path data, closed.")
      ]
    end

    def container(root:)
      fields = [
        field("name", "Name", "text", optional: true),
        *shape_fields,
        field("visible", "Drawn", "toggle", default: true, hint: "Off, the container is a construction line: it still derives regions and anchors children."),
        field("slot", "Colour slot", "select", options: SLOTS, optional: true, default: "ground")
      ]
      fields += placement unless root
      fields
    end

    def region(kind)
      common = [ field("name", "Name", "text", optional: true) ]
      by_kind = case kind
      when "rule"
        [ field("distance", "Distance", "number", step: 1, hint: "From the container's edge; outward is positive."),
          field("weight", "Weight", "number", step: 0.5, optional: true, default: 2),
          field("visible", "Drawn", "toggle", default: true) ]
      when "band"
        [ field("outer", "Outer edge", "number", step: 1, hint: "Distance of the outer edge from the container's edge."),
          field("width", "Width", "number", step: 1, hint: "Measured inward from the outer edge."),
          field("visible", "Drawn", "toggle", default: false) ]
      when "interior"
        [ field("inside", "Inset", "number", step: 1, optional: true, hint: "Zero or an inward offset, as a negative number."),
          field("visible", "Drawn", "toggle", default: false) ]
      end
      common + by_kind + [ field("slot", "Colour slot", "select", options: SLOTS, optional: true, default: (kind == "rule" ? "ink" : "field")) ]
    end

    def type(mode)
      common = [
        field("text", "Text", "text"),
        field("font", "Font", "font"),
        field("name", "Name", "text", optional: true)
      ]
      by_mode = case mode
      when "follow"
        [ field("region", "Follows", "region", of: "band"),
          field("from", "Baseline from", "select", options: [ %w[inner inner], %w[outer outer] ], optional: true, default: "inner"),
          field("inset", "Inset", "number", step: 1, optional: true, hint: "From that edge to the baseline."),
          field("size", "Size", "number", step: 1, optional: true, hint: "Blank fits the cap height to the band; a number sets it."),
          field("sweep", "Sweep", "sweep", hint: "Over the top, under the bottom, all the way round, or between two angles."),
          field("reversed", "Reversed", "toggle", default: false, optional: true),
          field("align", "Set within the sweep", "select", options: %w[start center end justify].map { |a| [ a, a.humanize ] }, optional: true, default: "center"),
          field("tracking", "Tracking", "number", step: 1, optional: true, hint: "Between letters, in units; justify solves it.") ]
      when "fit"
        [ field("region", "Fitted to", "region", of: "interior", optional: true),
          field("fit", "Fit", "select", options: Badger::Spec::FITS.map { |f| [ f, f.humanize ] }, optional: true, default: "chord_at_y"),
          field("at", "At", "number", step: 1, hint: "The height of the chord for a chord at y; its position across for a chord at x.",
                when: { key: "fit", in: %w[chord_at_y chord_at_x chord_at_x_per_glyph] }),
          field("height", "Height", "number", step: 1, optional: true, when: { key: "fit", in: %w[chord_at_y box] }),
          field("width", "Width", "number", step: 1, optional: true, when: { key: "fit", in: %w[chord_at_x box] }),
          field("axes", "Scaled on", "select", options: %w[width height both].map { |a| [ a, a ] }, optional: true, default: "width", when: { key: "fit", in: %w[box] }),
          field("stretch", "Stretch", "stretch", optional: true, hint: "How far the width may leave the height, as a range."),
          field("inset", "Inset", "number", step: 1, optional: true, when: { key: "fit", in: %w[chord_at_y chord_at_x chord_at_x_per_glyph] }),
          field("fill", "Fill", "number", step: 0.05, optional: true, default: 1, hint: "How much of the chord the line takes.",
                when: { key: "fit", in: %w[chord_at_y chord_at_x chord_at_x_per_glyph] }),
          field("edge", "Chord chosen", "select", options: [ %w[center center], %w[narrowest narrowest] ], optional: true, default: "center",
                when: { key: "fit", in: %w[chord_at_y chord_at_x chord_at_x_per_glyph] }),
          field("tracking", "Tracking", "number", step: 1, optional: true, when: { key: "fit", in: %w[chord_at_x_per_glyph] }),
          field("max_size", "At most", "number", step: 1, optional: true, hint: "A size the type will not grow past.") ]
      when "fixed"
        [ field("size", "Size", "number", step: 1) ]
      end
      fields = common + by_mode + [ field("slot", "Colour slot", "select", options: SLOTS, optional: true, default: "ink") ]
      fields += placement if mode == "fixed"
      fields += placement.map { |f| f.merge(when: { key: "fit", in: %w[box] }) } if mode == "fit"
      fields
    end

    def illustration
      [
        field("name", "Name", "text", optional: true),
        field("svg", "Artwork", "textarea", hint: "SVG markup. One colour takes a slot; more than one passes through as it is."),
        field("scale", "Scale", "number", step: 0.05, optional: true),
        field("fit.width", "Fit to width", "number", step: 1, optional: true),
        field("fit.height", "Fit to height", "number", step: 1, optional: true),
        field("slot", "Colour slot", "select", options: SLOTS, optional: true, default: "ink"),
        *placement
      ]
    end

    # The whole schema, keyed by what an entry is.
    def schema
      {
        "container" => container(root: true),
        "child" => container(root: false),
        "rule" => region("rule"), "band" => region("band"), "interior" => region("interior"),
        "follow" => type("follow"), "fit" => type("fit"), "fixed" => type("fixed"),
        "illustration" => illustration
      }
    end

    # What a new entry starts as, so "+ Type" gives something that draws.
    def starters(font:)
      {
        "rule" => { "kind" => "rule", "distance" => 0, "weight" => 2 },
        "band" => { "kind" => "band", "name" => "band", "outer" => -8, "width" => 40 },
        "interior" => { "kind" => "interior", "name" => "field", "inside" => -20 },
        "follow" => { "mode" => "follow", "text" => "TEXT", "font" => font, "inset" => 7, "sweep" => "top", "align" => "justify" },
        "fit" => { "mode" => "fit", "text" => "A", "font" => font, "fit" => "chord_at_y", "at" => 0, "inset" => 20 },
        "fixed" => { "mode" => "fixed", "text" => "1912", "font" => font, "size" => 24, "at" => "centroid" },
        "child" => { "name" => "child", "shape" => { "kind" => "circle", "radius" => 60 }, "at" => "centroid", "visible" => false },
        "illustration" => { "name" => "artwork", "svg" => "<svg viewBox=\"0 0 10 10\"><circle cx=\"5\" cy=\"5\" r=\"5\"/></svg>", "fit" => { "width" => 60 }, "at" => "centroid" }
      }
    end
  end
end
