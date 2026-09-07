require "yaml"

module Badger
  # What a badge starts from: a composition, not a blank document. Each is a
  # real document the core renders, with a placeholder word in it, so the
  # card that shows it never drifts from what choosing it gives; and each
  # names the reference it is after. A composition is drawn on its own
  # shape, and any of the shapes can be put under it: regions derive from
  # whatever the container is.
  module Compositions
    module_function

    Composition = Data.define(:key, :name, :note, :after, :frame, :shape) do
      def ratio = frame[0].to_f / frame[1]
    end

    SHAPES = {
      "circle" => "Circle", "ellipse" => "Ellipse", "superellipse" => "Superellipse", "rectangle" => "Rectangle",
      "rounded_rectangle" => "Rounded", "lozenge" => "Lozenge", "shield" => "Shield", "path" => "Path…"
    }.freeze

    ALL = [
      Composition.new("ring", "Ring", "Type follows the band over the top and back under the bottom; a pair holds the sides.",
        "Stockholm Stadion", [ 400, 480 ], "superellipse"),
      Composition.new("medallion", "Medallion", "A ring with a child container in the field: one letter or a mark.",
        "Salt & Sierra", [ 420, 420 ], "circle"),
      Composition.new("stack", "Lozenge stack", "Lines down a tall lozenge, each taking the chord at its height.",
        "Le Dive", [ 280, 560 ], "lozenge"),
      Composition.new("word", "Wide word", "One word across a wide lozenge, each letter the chord at its position.",
        "Giletti", [ 640, 280 ], "lozenge"),
      Composition.new("shield", "Shield band", "A straight top edge to set along, and a field below it.",
        nil, [ 400, 460 ], "shield"),
      Composition.new("plate", "Plate", "A rounded plate with a block of lines across it.",
        nil, [ 560, 320 ], "rounded_rectangle")
    ].freeze

    def all = ALL
    def find(key) = ALL.find { |c| c.key == key.to_s }
    def default = ALL.first

    # The shape of a kind at a composition's frame: what a circle, a lozenge
    # or a shield is when it has to be about this wide and this tall. A
    # circle cannot be both, so it is as big as the longer side: everything
    # the composition places inside the frame is then still inside it.
    def shape_for(kind, frame, path: nil)
      width, height = frame
      least = [ width, height ].min
      case kind.to_s
      when "circle" then { "kind" => "circle", "radius" => [ width, height ].max / 2 }
      when "ellipse" then { "kind" => "ellipse", "rx" => width / 2, "ry" => height / 2 }
      when "superellipse" then { "kind" => "superellipse", "width" => width, "height" => height, "exponent" => 2.2 }
      when "rectangle" then { "kind" => "rectangle", "width" => width, "height" => height }
      when "rounded_rectangle" then { "kind" => "rounded_rectangle", "width" => width, "height" => height, "radius" => least / 8 }
      when "lozenge" then { "kind" => "lozenge", "width" => width, "height" => height, "radius" => least / 12 }
      when "shield" then { "kind" => "shield", "width" => width, "height" => height }
      when "path"
        raise Badger::Error, "a path shape needs its path data" if path.to_s.strip.empty?
        { "kind" => "path", "d" => path.to_s.strip }
      else raise Badger::Error, "no such shape: #{kind}"
      end
    end

    # The document a composition gives, on a shape, in a font.
    def document(key, font:, shape: nil, path: nil)
      composition = find(key) or raise Badger::Error, "no such composition: #{key}"
      doc = YAML.safe_load(send(composition.key, font: font))
      { "name" => doc["name"], "shape" => shape_for(shape || composition.shape, composition.frame, path: path) }.merge(doc)
    end

    def ring(font:)
      <<~YAML
        name: Ring
        regions:
          - { kind: rule, name: edge, distance: 0, weight: 5 }
          - { kind: band, name: ring, outer: -10, width: 64 }
          - { kind: rule, name: inner, distance: -76, weight: 2 }
          - { kind: interior, name: field, inside: -80 }
        type:
          - { mode: follow, text: YOUR TOWN, font: #{font}, region: ring, inset: 12, sweep: top, align: justify, name: top }
          - { mode: follow, text: SINCE 1912, font: #{font}, region: ring, from: outer, inset: 12, reversed: true, sweep: bottom, align: justify, name: bottom }
          - { mode: fit, fit: chord_at_y, text: "19  12", font: #{font}, region: field, at: 0, fill: 0.9, height: 60, stretch: { min: 0.6, max: 1.4 }, name: pair }
      YAML
    end

    def medallion(font:)
      <<~YAML
        name: Medallion
        regions:
          - { kind: rule, name: edge, distance: 0, weight: 5 }
          - { kind: band, name: ring, outer: -10, width: 56 }
          - { kind: rule, name: inner, distance: -68, weight: 2 }
          - { kind: interior, name: field, inside: -72 }
        type:
          - { mode: follow, text: MEDALLION, font: #{font}, region: ring, inset: 10, sweep: top, align: justify, name: top }
          - { mode: follow, text: SINCE 1912, font: #{font}, region: ring, from: outer, inset: 10, reversed: true, sweep: bottom, align: justify, name: bottom }
        children:
          - name: mark
            shape: { kind: circle, radius: 110 }
            visible: false
            at: centroid
            regions:
              - { kind: interior, name: field, inside: 0 }
            type:
              - { mode: fit, fit: chord_at_x, text: M, font: #{font}, region: field, at: 0, inset: 20, name: letter }
      YAML
    end

    def stack(font:)
      lines = [ [ "THE", -190, 40, 0.6 ], [ "TALL", -90, 96, 0.6 ], [ "ONE", 30, 96, 0.6 ], [ "1912", 170, 40, 0.6 ] ]
      <<~YAML
        name: Lozenge stack
        regions:
          - { kind: rule, name: edge, distance: 0, weight: 4 }
          - { kind: interior, name: field, inside: -16 }
        type:
        #{lines.map { |text, y, height, min| "  - { mode: fit, fit: chord_at_y, text: \"#{text}\", font: #{font}, region: field, at: #{y}, height: #{height}, fill: 0.6, stretch: { min: #{min}, max: 2.2 }, name: \"#{text}\" }" }.join("\n")}
      YAML
    end

    def word(font:)
      <<~YAML
        name: Wide word
        regions:
          - { kind: rule, name: edge, distance: 0, weight: 4 }
          - { kind: rule, name: inner, distance: -12, weight: 2 }
          - { kind: interior, name: field, inside: -14 }
        type:
          - { mode: fit, fit: chord_at_x_per_glyph, text: WIDEWORD, font: #{font}, region: field, at: 0,
              fill: 0.67, inset: 12, tracking: 10, edge: narrowest, stretch: { min: 0.6, max: 2.3 }, name: word }
      YAML
    end

    def shield(font:)
      <<~YAML
        name: Shield band
        regions:
          - { kind: rule, name: edge, distance: 0, weight: 5 }
          - { kind: rule, name: inner, distance: -14, weight: 2 }
          - { kind: interior, name: field, inside: -18 }
        type:
          - { mode: fit, fit: chord_at_y, text: SHIELD, font: #{font}, region: field, at: -150, height: 60, fill: 0.8, stretch: { min: 0.7, max: 1.3 }, name: top }
          - { mode: fit, fit: chord_at_y, text: S, font: #{font}, region: field, at: 40, height: 200, fill: 0.5, stretch: { min: 0.8, max: 1.2 }, name: letter }
      YAML
    end

    def plate(font:)
      <<~YAML
        name: Plate
        regions:
          - { kind: rule, name: edge, distance: 0, weight: 4 }
          - { kind: rule, name: inner, distance: -14, weight: 2 }
          - { kind: interior, name: field, inside: -24 }
        type:
          - { mode: fit, fit: chord_at_y, text: THE, font: #{font}, region: field, at: -80, height: 36, fill: 0.3, stretch: { min: 0.6, max: 1.4 }, name: line1 }
          - { mode: fit, fit: chord_at_y, text: PLATE, font: #{font}, region: field, at: 10, height: 110, fill: 0.8, stretch: { min: 0.6, max: 1.6 }, name: line2 }
          - { mode: fit, fit: chord_at_y, text: EST 1912, font: #{font}, region: field, at: 100, height: 30, fill: 0.4, stretch: { min: 0.6, max: 1.4 }, name: line3 }
      YAML
    end
  end
end
