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
#   group    which of the panel's four groups the field is in: what the
#            entry is, where it goes, how it is set, how it looks
#   more     true for a field kept behind "More" until it is wanted
#   handle   the handle on the drawing the field is the number of, so the
#            two can light each other up
#   factor   a number shown at a multiple of what is written: 100 for a
#            fraction shown as a percentage
module Badger
  module Editor
    module_function

    SLOTS = [ %w[ground ground], %w[field field], %w[ink ink] ].freeze
    ALIGNS = %w[center top bottom left right top_left top_right bottom_left bottom_right].freeze
    GROUPS = %w[what where how look].freeze

    def field(key, label, type = "number", **options) = { key: key, label: label, type: type, group: "what" }.merge(options)

    def placement
      [
        field("at", "Placed at", "locator", group: "where", handle: "anchor",
              hint: "A point in the parent: its centroid, a polar angle and radius, a fraction of its bounds, or a point along its path."),
        field("align", "Aligned by", "align", group: "where", hint: "Which of the child's nine reference points lands on that point."),
        field("rotate", "Rotated", "number", step: 1, unit: "°", optional: true, group: "where", more: true, hint: "Degrees about the reference point; blank for none.")
      ]
    end

    def shape_fields
      [
        field("shape.kind", "Shape", "select", options: Badger::Spec::SHAPES.map { |k| [ k, k.humanize ] }),
        field("shape.radius", "Radius", "number", step: 1, handle: "shape:x", when: { key: "shape.kind", in: %w[circle] }),
        field("shape.rx", "Radius across", "number", step: 1, handle: "shape:x", when: { key: "shape.kind", in: %w[ellipse] }),
        field("shape.ry", "Radius down", "number", step: 1, handle: "shape:y", when: { key: "shape.kind", in: %w[ellipse] }),
        field("shape.rotation", "Rotation", "number", step: 1, unit: "°", optional: true, more: true, when: { key: "shape.kind", in: %w[ellipse] }),
        field("shape.width", "Width", "number", step: 1, handle: "shape:x", when: { key: "shape.kind", in: %w[rectangle lozenge rounded_rectangle superellipse shield] }),
        field("shape.height", "Height", "number", step: 1, handle: "shape:y", when: { key: "shape.kind", in: %w[rectangle lozenge rounded_rectangle superellipse shield] }),
        field("shape.radius", "Corner radius", "number", step: 1, optional: true, when: { key: "shape.kind", in: %w[lozenge] }),
        field("shape.radius", "Corner radius", "number", step: 1, when: { key: "shape.kind", in: %w[rounded_rectangle] }),
        field("shape.exponent", "Exponent", "number", step: 0.1, optional: true, when: { key: "shape.kind", in: %w[superellipse] },
              hint: "2 is an ellipse; higher is squarer."),
        field("shape.shoulder", "Shoulder", "number", step: 0.05, optional: true, more: true, when: { key: "shape.kind", in: %w[shield] }),
        field("shape.curve", "Curve", "number", step: 0.05, optional: true, more: true, when: { key: "shape.kind", in: %w[shield] }),
        field("shape.d", "Path", "textarea", when: { key: "shape.kind", in: %w[path] }, hint: "SVG path data, closed.")
      ]
    end

    def container(root:)
      fields = [
        field("name", "Name", "text", optional: true),
        *shape_fields,
        field("visible", "Drawn", "toggle", default: true, group: "look", hint: "Off, the container is a construction line: it still derives regions and anchors children."),
        field("slot", "Colour slot", "select", options: SLOTS, optional: true, default: "ground", group: "look")
      ]
      fields += placement unless root
      fields
    end

    def region(kind)
      common = [ field("name", "Name", "text", optional: true) ]
      by_kind = case kind
      when "rule"
        [ field("distance", "Distance", "number", step: 1, group: "where", handle: "rule:distance", hint: "From the container's edge; outward is positive."),
          field("weight", "Weight", "number", step: 0.5, optional: true, default: 2, group: "look"),
          field("visible", "Drawn", "toggle", default: true, group: "look") ]
      when "band"
        [ field("outer", "Outer edge", "number", step: 1, group: "where", handle: "band:outer", hint: "Distance of the outer edge from the container's edge."),
          field("width", "Width", "number", step: 1, group: "where", handle: "band:inner", hint: "Measured inward from the outer edge."),
          field("visible", "Drawn", "toggle", default: false, group: "look") ]
      when "interior"
        [ field("inside", "Inset", "number", step: 1, optional: true, group: "where", handle: "interior:inside", hint: "Zero or an inward offset, as a negative number."),
          field("visible", "Drawn", "toggle", default: false, group: "look") ]
      end
      common + by_kind + [ field("slot", "Colour slot", "select", options: SLOTS, optional: true, default: (kind == "rule" ? "ink" : "field"), group: "look") ]
    end

    def type(mode)
      common = [
        field("text", "Text", "text"),
        field("font", "Font", "font"),
        field("name", "Name", "text", optional: true, more: true)
      ]
      by_mode = case mode
      when "follow"
        [ field("region", "Follows", "region", of: "band", group: "where"),
          field("sweep", "Sweep", "sweep", group: "where", handle: "sweep:from sweep:to", hint: "Over the top, under the bottom, all the way round, or a centre and a span in degrees."),
          field("from", "Baseline from", "select", options: [ %w[inner inner], %w[outer outer] ], optional: true, default: "inner", group: "where"),
          field("inset", "Inset", "number", step: 1, optional: true, group: "where", hint: "From that edge to the baseline."),
          field("size", "Size", "number", step: 1, optional: true, group: "how", hint: "Blank fits the cap height to the band; a number sets it."),
          field("align", "Set within the sweep", "select", options: %w[start center end justify].map { |a| [ a, a.humanize ] }, optional: true, default: "center", group: "how"),
          field("tracking", "Tracking", "number", step: 1, optional: true, group: "how", hint: "Between letters, in units; justify solves it."),
          field("reversed", "Reversed", "toggle", default: false, optional: true, group: "how", more: true, hint: "The run goes the other way round, for reading under the bottom.") ]
      when "fit"
        [ field("region", "Fitted to", "region", of: "interior", optional: true, group: "where"),
          field("fit", "Fit", "select", options: Badger::Spec::FITS.map { |f| [ f, f.humanize ] }, optional: true, default: "chord_at_y", group: "where"),
          field("at", "At", "number", step: 1, group: "where", handle: "chord:at", hint: "The height of the chord for a chord at y; its position across for a chord at x.",
                when: { key: "fit", in: %w[chord_at_y chord_at_x chord_at_x_per_glyph] }),
          field("height", "Height", "number", step: 1, optional: true, group: "how", when: { key: "fit", in: %w[chord_at_y box] }),
          field("width", "Width", "number", step: 1, optional: true, group: "how", when: { key: "fit", in: %w[chord_at_x box] }),
          field("axes", "Scaled on", "select", options: %w[width height both].map { |a| [ a, a ] }, optional: true, default: "width", group: "how", when: { key: "fit", in: %w[box] }),
          field("fill", "Fill", "number", step: 5, factor: 100, unit: "%", optional: true, default: 100, group: "how", hint: "How much of the chord the line takes.",
                when: { key: "fit", in: %w[chord_at_y chord_at_x chord_at_x_per_glyph] }),
          field("inset", "Inset", "number", step: 1, optional: true, group: "where", more: true, when: { key: "fit", in: %w[chord_at_y chord_at_x chord_at_x_per_glyph] }),
          field("stretch", "Stretch", "stretch", optional: true, group: "how", more: true, hint: "How far the width may leave the height, as a range."),
          field("edge", "Chord chosen", "select", options: [ %w[center center], %w[narrowest narrowest] ], optional: true, default: "center", group: "where", more: true,
                when: { key: "fit", in: %w[chord_at_y chord_at_x chord_at_x_per_glyph] }),
          field("tracking", "Tracking", "number", step: 1, optional: true, group: "how", more: true, when: { key: "fit", in: %w[chord_at_x_per_glyph] }),
          field("max_size", "At most", "number", step: 1, optional: true, group: "how", more: true, hint: "A size the type will not grow past.") ]
      when "fixed"
        [ field("size", "Size", "number", step: 1, group: "how") ]
      end
      fields = common + by_mode + [ field("slot", "Colour slot", "select", options: SLOTS, optional: true, default: "ink", group: "look") ]
      fields += placement if mode == "fixed"
      fields += placement.map { |f| f.merge(when: { key: "fit", in: %w[box] }) } if mode == "fit"
      fields
    end

    def illustration
      [
        field("name", "Name", "text", optional: true),
        field("svg", "Artwork", "textarea", hint: "SVG markup. One colour takes a slot; more than one passes through as it is."),
        field("scale", "Scale", "number", step: 0.05, optional: true, group: "how"),
        field("fit.width", "Fit to width", "number", step: 1, optional: true, group: "how"),
        field("fit.height", "Fit to height", "number", step: 1, optional: true, group: "how"),
        field("slot", "Colour slot", "select", options: SLOTS, optional: true, default: "ink", group: "look"),
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
